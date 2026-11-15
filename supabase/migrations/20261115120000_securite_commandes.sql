-- H MODE — sécurité des commandes et des limites (audit de sécurité du 15/11/2026). Rejouable.
--   · empreinte du visiteur : la 1ʳᵉ adresse de X-Forwarded-For est écrite par le visiteur lui-même (falsifiable) ;
--     on prend cf-connecting-ip (posé par Cloudflare, devant Supabase), sinon la DERNIÈRE adresse de X-Forwarded-For
--     (ajoutée par le proxy), sinon x-real-ip ;
--   · plafond global des commandes : il ne bloque plus tous les clients. Au-delà, la commande est enregistrée et
--     marquée « à vérifier » (colonne a_verifier) ; le robot le signale. La limite par visiteur reste un refus (429) ;
--   · republication_necessaire passe par la limite du robot avant tout calcul bcrypt (appelable sans compte).

-- ── Empreinte du visiteur ─────────────────────────────────────────────────────────────────────────
create or replace function public.empreinte_visiteur() returns text
language plpgsql stable security definer set search_path = '' as $$
declare
  entetes json := nullif(current_setting('request.headers', true), '')::json;
  ip text := coalesce(
    nullif(trim(entetes ->> 'cf-connecting-ip'), ''),
    nullif(trim(regexp_replace(coalesce(entetes ->> 'x-forwarded-for', ''), '^.*,', '')), ''),
    nullif(trim(entetes ->> 'x-real-ip'), ''),
    '');
  base text;
begin
  base := case when ip <> '' then 'ip:' || ip
               when auth.uid() is not null then 'compte:' || auth.uid()::text
               else 'inconnu' end;
  return encode(extensions.digest(convert_to(base, 'UTF8') || (select s.sel from public.sel_empreinte s), 'sha256'), 'hex');
end $$;
revoke all on function public.empreinte_visiteur() from public, anon, authenticated;

-- ── Commandes reçues au-delà du plafond horaire ───────────────────────────────────────────────────
alter table public.commandes add column if not exists a_verifier boolean not null default false;

-- 'bloque' : limite de ce visiteur atteinte (HTTP 429, blocage noté) ; 'afflux' : plafond global dépassé, la commande
-- passe mais sera marquée ; 'ok' sinon. Un afflux ne bloque jamais les autres clients.
create or replace function public.limite_commande() returns text
language plpgsql volatile security definer set search_path = '' as $$
declare
  l public.limites;
  e text := public.empreinte_visiteur();
  n integer;
  total integer := 0;
begin
  select * into l from public.limites where action = 'commande';
  if not found then return 'ok'; end if;
  delete from public.limites_evenements where cree_le < now() - interval '30 days';
  select count(*) into n from public.limites_evenements
   where action = 'commande' and empreinte = e and not limites_evenements.bloque and cree_le > now() - make_interval(mins => l.fenetre_minutes);
  if n >= l.maximum then
    insert into public.limites_evenements (action, empreinte, bloque) values ('commande', e, true);
    perform set_config('response.status', '429', true);
    perform set_config('response.headers', format('[{"Retry-After": "%s"}]', l.fenetre_minutes * 60), true);
    return 'bloque';
  end if;
  if l.maximum_global is not null then
    select count(*) into total from public.limites_evenements
     where action = 'commande' and not limites_evenements.bloque and cree_le > now() - make_interval(mins => l.fenetre_minutes);
  end if;
  insert into public.limites_evenements (action, empreinte, bloque) values ('commande', e, false);
  return case when l.maximum_global is not null and total >= l.maximum_global then 'afflux' else 'ok' end;
end $$;
revoke all on function public.limite_commande() from public, anon, authenticated;

-- ── passer_commande v4 : v3 + limite_commande() (afflux marqué au lieu d'un refus général) ─────────
create or replace function public.passer_commande(commande jsonb) returns text
language plpgsql security definer set search_path = '' as $$
declare
  c jsonb := commande -> 'client';
  l jsonb;
  p record;
  villes jsonb;
  etat text;
  nouvel_id uuid;
  total integer := 0;
  lignes jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(commande -> 'lignes') is distinct from 'array' or jsonb_array_length(commande -> 'lignes') not between 1 and 50 then
    raise exception 'Commande vide ou trop longue.' using errcode = '22023';
  end if;
  etat := public.limite_commande();
  if etat = 'bloque' then
    return null; -- limite de CE visiteur : HTTP 429, rien n'est enregistré
  end if;

  select r.valeur -> 'livraison' -> 'villes' into villes from public.reglages r where r.cle = 'boutique';
  if jsonb_typeof(villes) = 'array' and not (villes ? coalesce(c ->> 'ville', '')) then
    raise exception 'Ville non livrée : %', c ->> 'ville' using errcode = '22023';
  end if;

  for l in select * from jsonb_array_elements(commande -> 'lignes') loop
    select pr.nom, pr.prix_dh, pr.publie, pr.coloris, pr.tailles into p from public.produits pr where pr.slug = l ->> 'slug';
    if not found or not p.publie or p.prix_dh is null then
      raise exception 'Pièce indisponible à la commande : %', l ->> 'slug' using errcode = '22023';
    end if;
    if jsonb_array_length(p.coloris) > 0 and not exists (select 1 from jsonb_array_elements(p.coloris) x where x ->> 'nom' = l ->> 'coloris') then
      raise exception 'Coloris inconnu pour %', l ->> 'slug' using errcode = '22023';
    end if;
    if jsonb_array_length(p.tailles) > 0 and not exists (select 1 from jsonb_array_elements(p.tailles) x where x ->> 'taille' = l ->> 'taille' and coalesce((x ->> 'disponible')::boolean, true)) then
      raise exception 'Taille indisponible pour %', l ->> 'slug' using errcode = '22023';
    end if;
    total := total + (l ->> 'quantite')::integer * p.prix_dh;
    lignes := lignes || jsonb_build_array(l || jsonb_build_object('prix_dh', p.prix_dh, 'nom', p.nom));
  end loop;

  insert into public.commandes (reference, utilisateur, nom, telephone, email, ville, adresse, instructions, sous_total_dh, a_verifier)
  values (commande ->> 'reference', auth.uid(), trim(c ->> 'nom'), trim(c ->> 'telephone'), coalesce(trim(c ->> 'email'), ''),
          c ->> 'ville', trim(c ->> 'adresse'), coalesce(trim(c ->> 'instructions'), ''), total, etat = 'afflux')
  returning id into nouvel_id;

  insert into public.lignes_commande (commande, slug, nom, coloris, taille, quantite, prix_dh)
  select nouvel_id, x ->> 'slug', x ->> 'nom', x ->> 'coloris', x ->> 'taille', (x ->> 'quantite')::integer, (x ->> 'prix_dh')::integer
  from jsonb_array_elements(lignes) x;

  return commande ->> 'reference';
end $$;
revoke all on function public.passer_commande(jsonb) from public;
grant execute on function public.passer_commande(jsonb) to anon, authenticated;

-- ── Robot : + alerte quand des commandes « à vérifier » arrivent ──────────────────────────────────
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
  -- Activité suspecte depuis 30 min : blocages de limite, erreurs du site en rafale, clé admin.
  select count(*) into n from public.limites_evenements where bloque and cree_le > now() - interval '30 minutes';
  if n >= 10 then alertes := alertes || jsonb_build_array(format('%s requêtes bloquées par les limites en 30 min', n)); end if;
  select count(*) into n from public.erreurs_site where cree_le > now() - interval '30 minutes';
  if n >= 50 then alertes := alertes || jsonb_build_array(format('%s erreurs du site en 30 min', n)); end if;
  select count(*) into n from public.evenements_techniques where categorie = 'securite' and gravite = 'critique' and cree_le > now() - interval '30 minutes';
  if n > 0 then alertes := alertes || jsonb_build_array('Accès admin bloqué après des clés erronées (30 dernières minutes)'); end if;
  -- Afflux de commandes : au-delà du plafond horaire, les commandes passent mais sont marquées « à vérifier ».
  select count(*) into n from public.commandes where a_verifier and cree_le > now() - interval '30 minutes';
  if n > 0 then alertes := alertes || jsonb_build_array(format('%s commande(s) reçue(s) au-delà du plafond horaire : à vérifier dans l''admin', n)); end if;
  -- Sauvegardes : rappel une fois par jour (passage de 9 h, heure du Maroc), pas toutes les 30 min.
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

-- ── Republication : limite du robot avant le calcul bcrypt ────────────────────────────────────────
create or replace function public.republication_necessaire(jeton text, construit_le timestamptz) returns boolean
language plpgsql volatile security definer set search_path = '' as $$
declare
  modifie timestamptz;
  derniere timestamptz;
begin
  if not public.passer_limite('controle_robot') then return false; end if;
  if not public.jeton_robot_valide(jeton) then return false; end if;
  select max(maj_le) into modifie from public.produits;
  select max(cree_le) into derniere from public.republications;
  if modifie is null or construit_le is null or modifie <= construit_le then return false; end if;
  if derniere is not null and derniere > now() - interval '12 hours' then return false; end if; -- au plus un build toutes les 12 h
  insert into public.republications (raison) values (format('catalogue modifié le %s, build du %s', modifie, construit_le));
  return true;
end $$;
revoke all on function public.republication_necessaire(text, timestamptz) from public;
grant execute on function public.republication_necessaire(text, timestamptz) to anon, authenticated;
