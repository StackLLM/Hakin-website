-- Robot de surveillance : un passage par heure au lieu de deux (quota GitHub Actions d'un dépôt privé gratuit).
-- Les fenêtres d'alerte passent de 30 à 60 min, avec des seuils doublés (même rythme qu'avant) ; un contrôle devient
-- « inconnu » après 135 min sans nouvelles (un passage manqué + le retard habituel de GitHub).

create or replace function public.enregistrer_controles(jeton text, resultats jsonb) returns jsonb
language plpgsql volatile security definer set search_path = '' as $$
declare
  r jsonb;
  alertes jsonb := '[]'::jsonb;
  n integer;
  heure_locale timestamp := now() at time zone 'Africa/Casablanca';
  derniere timestamptz;
begin
  if not public.passer_limite('controle_robot') then
    return jsonb_build_object('ok', false, 'message', 'Trop d''envois.');
  end if;
  if not public.jeton_robot_valide(jeton) then
    return jsonb_build_object('ok', false, 'message', 'Jeton refusé.');
  end if;
  if jsonb_typeof(resultats) is distinct from 'array' or jsonb_array_length(resultats) > 20 then
    return jsonb_build_object('ok', false, 'message', 'Résultats invalides.');
  end if;
  delete from public.controles_sante where cree_le < now() - interval '30 days';
  for r in select * from jsonb_array_elements(resultats) loop
    insert into public.controles_sante (source, cible, ok, statut_http, duree_ms, detail)
    values ('robot', left(coalesce(r ->> 'cible', '?'), 60), coalesce((r ->> 'ok')::boolean, false),
            nullif(r ->> 'statut_http', '')::integer, nullif(r ->> 'duree_ms', '')::integer, public.nettoyer_texte(r ->> 'detail', 300));
    if r ? 'version' then perform public.noter_version(r); end if;
    if not coalesce((r ->> 'ok')::boolean, false) then
      alertes := alertes || jsonb_build_array(format('%s en échec : %s', r ->> 'cible', coalesce(r ->> 'detail', '')));
    else
      -- Dégradé : les 3 derniers passages du robot sur ce contrôle dépassent le seuil de lenteur.
      select count(*) into n from (
        select duree_ms from public.controles_sante where source = 'robot' and cible = left(r ->> 'cible', 60)
        order by cree_le desc limit 3) x
       where x.duree_ms > public.seuil_lent_ms(r ->> 'cible');
      if n = 3 then alertes := alertes || jsonb_build_array(format('%s lent : plus de %s ms trois fois de suite', r ->> 'cible', public.seuil_lent_ms(r ->> 'cible'))); end if;
    end if;
  end loop;
  -- Activité suspecte depuis 60 min (un passage du robot par heure) : blocages de limite, erreurs du site en rafale, clé admin.
  select count(*) into n from public.limites_evenements where bloque and cree_le > now() - interval '60 minutes';
  if n >= 20 then alertes := alertes || jsonb_build_array(format('%s requêtes bloquées par les limites en 1 h', n)); end if;
  select count(*) into n from public.erreurs_site where cree_le > now() - interval '60 minutes';
  if n >= 100 then alertes := alertes || jsonb_build_array(format('%s erreurs du site en 1 h', n)); end if;
  select count(*) into n from public.evenements_techniques where categorie = 'securite' and gravite = 'critique' and cree_le > now() - interval '60 minutes';
  if n > 0 then alertes := alertes || jsonb_build_array('Accès admin bloqué après des clés erronées (dernière heure)'); end if;
  -- Afflux de commandes : au-delà du plafond horaire, les commandes passent mais sont marquées « à vérifier ».
  select count(*) into n from public.commandes where a_verifier and cree_le > now() - interval '60 minutes';
  if n > 0 then alertes := alertes || jsonb_build_array(format('%s commande(s) reçue(s) au-delà du plafond horaire : à vérifier dans l''admin', n)); end if;
  -- Sauvegardes : rappel une fois par jour (passage de 9 h, heure du Maroc), pas à chaque passage.
  if extract(hour from heure_locale) = 9 and extract(minute from heure_locale) < 30 then
    select max(cree_le) into derniere from public.sauvegardes where type = 'manuelle';
    if derniere is null or derniere < now() - interval '8 days' then
      alertes := alertes || jsonb_build_array('Aucune sauvegarde de la base depuis plus de 8 jours');
    end if;
    select max(cree_le) into derniere from public.sauvegardes where type = 'restauration_testee';
    if derniere is null or derniere < now() - interval '35 days' then
      alertes := alertes || jsonb_build_array('Restauration de sauvegarde non testée depuis plus de 35 jours');
    end if;
  end if;
  return jsonb_build_object('ok', true, 'alertes', alertes);
end $$;
revoke all on function public.enregistrer_controles(text, jsonb) from public;
grant execute on function public.enregistrer_controles(text, jsonb) to anon, authenticated;

-- ── État des services : inconnu après 135 min (le robot passe toutes les heures) ──────────────────
create or replace function public.etat_supervision() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare res jsonb;
begin
  if not public.est_admin_technique() then raise exception 'Réservé à la supervision technique.' using errcode = '42501'; end if;
  with derniers as (
    select distinct on (cible) cible, cree_le, ok, duree_ms, statut_http, detail, source
    from public.controles_sante order by cible, cree_le desc
  ), stats as (
    select cible,
      count(*) filter (where cree_le > now() - interval '24 hours') as n24,
      count(*) filter (where cree_le > now() - interval '24 hours' and ok) as ok24,
      count(*) filter (where cree_le > now() - interval '7 days') as n7,
      count(*) filter (where cree_le > now() - interval '7 days' and ok) as ok7,
      round(avg(duree_ms) filter (where cree_le > now() - interval '24 hours' and ok))::integer as moyenne24,
      (percentile_cont(0.95) within group (order by duree_ms) filter (where cree_le > now() - interval '24 hours' and ok))::integer as p95_24,
      count(*) filter (where cree_le > now() - interval '6 hours' and not ok) as echecs6h
    from public.controles_sante group by cible
  )
  select jsonb_build_object(
    'services', (select coalesce(jsonb_agg(jsonb_build_object(
        'cible', d.cible, 'dernier', d.cree_le, 'source', d.source, 'ok', d.ok, 'duree_ms', d.duree_ms, 'statut_http', d.statut_http, 'detail', d.detail,
        'seuil_ms', public.seuil_lent_ms(d.cible),
        'controles_24h', s.n24, 'disponibilite_24h', case when s.n24 > 0 then round(100.0 * s.ok24 / s.n24, 1) end,
        'controles_7j', s.n7, 'disponibilite_7j', case when s.n7 > 0 then round(100.0 * s.ok7 / s.n7, 1) end,
        'moyenne_ms_24h', s.moyenne24, 'p95_ms_24h', s.p95_24,
        'statut', case
          when d.cree_le < now() - interval '135 minutes' then 'inconnu'
          when not d.ok then 'indisponible'
          when d.duree_ms > public.seuil_lent_ms(d.cible) or s.echecs6h > 0 then 'degrade'
          else 'operationnel' end
      ) order by d.cible), '[]'::jsonb) from derniers d join stats s using (cible)),
    'tendance', (select coalesce(jsonb_agg(x order by x.heure), '[]'::jsonb) from (
        select date_trunc('hour', cree_le) as heure,
          round(avg(duree_ms) filter (where cible like 'site :%' and ok))::integer as site_ms,
          round(avg(duree_ms) filter (where cible like 'base :%' and ok))::integer as base_ms,
          count(*) filter (where not ok) as echecs, count(*) as controles
        from public.controles_sante where cree_le > now() - interval '48 hours' group by 1) x),
    'dernier_robot', (select max(cree_le) from public.controles_sante where source = 'robot'),
    'deploiements', (select coalesce(jsonb_agg(x order by x.vu_le desc), '[]'::jsonb) from (select version, construit_le, vu_le from public.deploiements order by vu_le desc limit 10) x),
    'sauvegardes', jsonb_build_object(
      'derniere', (select max(cree_le) from public.sauvegardes where type = 'manuelle'),
      'derniere_restauration', (select max(cree_le) from public.sauvegardes where type = 'restauration_testee'),
      'dernier_echec', (select max(cree_le) from public.sauvegardes where type = 'echec')),
    'compteurs_24h', jsonb_build_object(
      'erreurs', (select count(*) from public.erreurs_site where cree_le > now() - interval '24 hours'),
      'erreurs_api', (select count(*) from public.erreurs_site where type = 'api' and cree_le > now() - interval '24 hours'),
      'controles_en_echec', (select count(*) from public.controles_sante where not ok and cree_le > now() - interval '24 hours'),
      'appels_publics', (select count(*) from public.limites_evenements where not bloque and cree_le > now() - interval '24 hours'),
      'appels_bloques', (select count(*) from public.limites_evenements where bloque and cree_le > now() - interval '24 hours'),
      'securite', (select count(*) from public.evenements_techniques where categorie = 'securite' and cree_le > now() - interval '24 hours')),
    'appels_par_action_24h', (select coalesce(jsonb_agg(x), '[]'::jsonb) from (
        select action, count(*) filter (where not bloque) as acceptes, count(*) filter (where bloque) as bloques
        from public.limites_evenements where cree_le > now() - interval '24 hours' group by action order by action) x)
  ) into res;
  return res;
end $$;
revoke all on function public.etat_supervision() from public;
grant execute on function public.etat_supervision() to authenticated;
