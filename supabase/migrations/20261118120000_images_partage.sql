-- H MODE — images de partage fabriquées par l'admin (lot 47, phase 2, lot 2.1). Rejouable.
-- La vignette d'un lien partagé (WhatsApp, Facebook) ne passe plus par un build Netlify : l'admin fabrique, à
-- l'enregistrement d'une pièce, une image JPEG 1200 × 630 rangée dans produits/partage/<slug>.jpg (lue par l'Edge
-- Function « apercu »). WhatsApp et Facebook lisent mal le WebP : ce dossier seul reçoit du JPEG.

do $$
begin
  if exists (select 1 from pg_namespace where nspname = 'storage') then
    update storage.buckets set allowed_mime_types = array['image/webp', 'image/jpeg'] where id = 'produits';
    -- Envoi : WebP partout (photos), JPEG seulement sous partage/<slug>.jpg.
    execute 'drop policy if exists "photos produits : écriture admin" on storage.objects';
    execute $p$create policy "photos produits : écriture admin" on storage.objects for insert to authenticated
      with check (bucket_id = 'produits' and (select public.est_admin())
                  and (name ~ '\.webp$' or name ~ '^partage/[a-z0-9]+(-[a-z0-9]+)*\.jpg$'))$p$;
    -- Remplacement (image de partage refaite quand la première photo change) : sous partage/ seulement.
    execute 'drop policy if exists "photos produits : remplacement image de partage" on storage.objects';
    execute $p$create policy "photos produits : remplacement image de partage" on storage.objects for update to authenticated
      using (bucket_id = 'produits' and name like 'partage/%' and (select public.est_admin()))
      with check (bucket_id = 'produits' and name ~ '^partage/[a-z0-9]+(-[a-z0-9]+)*\.jpg$' and (select public.est_admin()))$p$;
  end if;
end $$;
