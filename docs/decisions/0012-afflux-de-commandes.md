# 0012 — Un afflux de commandes ne bloque plus les clients ; empreinte du visiteur fiable
- Date : 2026-11-15
- Contexte : `passer_commande` refusait toute commande au-delà de 100 par heure, tous visiteurs confondus (ADR 0009).
  Une seule personne pouvait atteindre ce plafond et bloquer le site pour tout le monde pendant une heure, avec un
  message faux (« depuis cet appareil »). De plus, le visiteur était reconnu par la **première** adresse de
  `X-Forwarded-For`, que le visiteur écrit lui-même : la limite par visiteur se contournait en changeant l'en-tête.
- Décisions (migration `20261115120000_securite_commandes.sql`) :
  - **Limite par visiteur** : inchangée, elle refuse (HTTP 429, rien d'enregistré).
  - **Plafond global** : il ne refuse plus. Au-delà, la commande est enregistrée avec `a_verifier = true` ; l'admin la
    voit marquée « À vérifier », et le robot lève une alerte. `limite_commande()` remplace `passer_limite('commande')`.
  - **Empreinte du visiteur** : `cf-connecting-ip` (posé par Cloudflare, devant Supabase), sinon la **dernière** adresse
    de `X-Forwarded-For` (ajoutée par le proxy), sinon `x-real-ip`. Test local : deux en-têtes différents depuis la même
    machine donnent la même empreinte.
  - `republication_necessaire` passe par la limite du robot avant le calcul bcrypt (appelable sans compte).
  - Le message du site ne parle plus que de la limite de ce visiteur.
- Conséquences :
  - Un pic réel de ventes n'est plus refusé ; des fausses commandes en masse arrivent marquées, à trier.
  - Toute nouvelle écriture publique coûteuse passe par une limite **avant** son calcul.
  - Ce qui est mesuré en ligne pour l'empreinte dépend de Cloudflare : à revoir si Supabase change de réseau.
