# Publication admin → site client — plan par phases et par lots

> Faire en sorte que tout ce que l'admin change dans `/admin` arrive chez le client sans build : le site ouvert, la vignette des liens partagés, le plan du site pour Google.
> H MODE tourne sur Netlify (site), Supabase (base, photos, admin, et deux Edge Functions à créer) et GitHub (code, robot de surveillance).

- **Date** : 2026-11-18 (version 3 : vignettes et plan du site servis à la demande par Edge Function, plus aucun build lancé par l'admin)
- **Auteur** : Oussama (avec Claude)
- **Branche de travail** : `dev` → `main` après validation (PR, CI verte)
- **État** (2026-11-21) : **phase 1 faite et en ligne** (version `741ce9d`). **Lot 2.1 fait** (sur `dev`, non poussé ; migration locale seulement). Suite : lot 2.2.

---

## Sommaire

- [Le problème et le but](#but)
- [Décisions prises](#decisions-prises)
- [Ce qu'on a trouvé](#constat)
- [Comment les morceaux s'emboîtent](#architecture)
- [Phase 1 — Le site ouvert suit l'admin](#phase-1)
  - [Lot 1.1 — Relire le catalogue pendant la visite](#lot-1-1)
  - [Lot 1.2 — Dire à l'admin quand c'est visible](#lot-1-2)
- [Phase 2 — Vignettes et plan du site à la demande](#phase-2)
  - [Lot 2.1 — Image de partage fabriquée à l'enregistrement](#lot-2-1)
  - [Lot 2.2 — Edge Function `apercu` (vignette d'une pièce)](#lot-2-2)
  - [Lot 2.3 — Edge Function `sitemap-produits`](#lot-2-3)
  - [Lot 2.4 — Netlify relaie `/p/…` et le plan du site](#lot-2-4)
  - [Lot 2.5 — Le lien partagé devient `/p/<slug>`](#lot-2-5)
  - [Lot 2.6 — Retirer l'ancien chemin de republication](#lot-2-6)
  - [Lot 2.7 — Mise en service dans Supabase et Netlify](#lot-2-7)
  - [Test réel de la phase 2](#test-2)
- [Phase 3 — Preuve et suivi](#phase-3)
  - [Lot 3.1 — Test automatique admin → client](#lot-3-1)
  - [Lot 3.2 — Le robot surveille les vignettes et le plan du site](#lot-3-2)
  - [Lot 3.3 — Décision écrite et plan du projet](#lot-3-3)
- [Actions d'Oussama](#actions)
- [Points à confirmer en cours de route](#a-confirmer)
- [Décidé automatiquement](#decide)
- [Zone technique concernée](#zone-technique)

---

<a id="but"></a>
## Le problème et le but

**Aujourd'hui** : quand l'admin ajoute, change ou supprime une pièce, le client la voit sur le site dès qu'il l'ouvre, sans build et sans coût. Deux défauts restent :
- un client qui a déjà le site ouvert ne voit le changement qu'en rechargeant la page ;
- la **vignette d'un lien partagé** (WhatsApp, Facebook) et le **plan du site pour Google** sont fabriqués pendant le build. Ils restent en retard jusqu'à la prochaine mise en ligne de code. Les mettre à jour à chaque changement de l'admin coûterait 15 crédits Netlify par build, avec environ 20 builds par mois sur l'offre gratuite : un admin actif viderait le solde et le site se mettrait en pause.

**Le but** : ce que l'admin change est à jour partout, tout de suite, **sans aucun build**. Les builds ne servent plus qu'aux changements de code.

| Action | Build ? | Coût Netlify | Site client | Vignette du lien partagé | Plan du site Google |
|---|---|---|---|---|---|
| Admin ajoute, change ou supprime une pièce (après ce chantier) | non | 0 | à jour | à jour | à jour |
| Développeur met en ligne du code | oui | 15 crédits | — | — | — |

| Besoin | Où dans le produit |
|---|---|
| Le site déjà ouvert se met à jour | **Site client** (phase 1) |
| Vignettes et plan du site toujours à jour, sans build | **Edge Functions + Netlify** (phase 2) |
| L'admin sait quand c'est visible | **Admin** (lot 1.2) |
| Une preuve que la chaîne marche | **Tests et robot** (phase 3) |

Hors chantier : les types de vêtements et les collections ne sont pas modifiables dans l'admin aujourd'hui (fichiers `categories.json` et `collections.json`). Ils restent écrits au build.

---

<a id="decisions-prises"></a>
## Décisions prises

Décisions d'Oussama.

| # | Sujet | Choix | Conséquence dans le plan |
|---|---|---|---|
| 1 | ~~Qui déclenche la mise en ligne~~ (2026-11-18, **annulée le 2026-11-18**) | ~~Option C : la base prévient une Edge Function qui lance un build Netlify~~ — chaque build coûte 15 crédits ; un admin actif épuiserait le solde Netlify | Plus aucun build lancé par l'admin |
| 2 | ~~Option A : le robot GitHub lance le build, au plus toutes les 12 h~~ (2026-11-18, **remplacée**) | ~~Robot GitHub + secret GitHub~~ — trop lent, et même problème de crédits | Lot 2.6 retire cette étape du robot |
| 3 | Vignettes et plan du site (2026-11-18) | **À la demande** : deux Edge Functions Supabase les fabriquent depuis la base quand WhatsApp, Facebook ou Google les demandent ; Netlify relaie | Phase 2 refaite (lots 2.1 à 2.7). Aucun build hook, aucun secret à ranger |
| 4 | Site déjà ouvert (2026-11-18) | **A** : relecture au retour sur l'onglet et toutes les 5 min (pas de Realtime) | Lot 1.1 |

---

<a id="constat"></a>
## Ce qu'on a trouvé

**Fait** — vérifié dans le code et sur GitHub le 2026-11-18.

### Ce qui marche déjà
- **Déjà là** : à chaque ouverture, le site affiche la dernière copie gardée sur l'appareil, puis lit Supabase et remplace (`lib/donnees.ts`, `chargerDonnees`). Produits, réglages, textes et photos (Supabase Storage) passent par là.
- **Déjà là** : si le contenu reçu est identique, la page ne se remonte pas, donc une saisie en cours n'est pas perdue (`appliquerDonnees`).
- **Déjà là** : `pages-partage.mjs` écrit au build, pour chaque pièce publiée, une page `produit/<slug>.html` avec ses balises de partage et une image JPEG 1200 × 630 dans `partage/`.
- **Déjà là** : les photos téléversées dans l'admin sont redimensionnées dans le navigateur (`features/admin/photos.ts`, WebP 480 et 960) avant d'aller dans le bucket `produits`.

### Ce que le build lit, et rien d'autre
- Par pièce publiée : `slug`, `nom`, `marque`, `prix_dh`, `description` (140 premiers caractères) et la première photo (`images[0]`). Vérifié dans `pages-partage.mjs`.
- Le plan du site (`sitemap.mjs`) lit seulement `src/data/produits.json` : une pièce créée dans l'admin n'y entre jamais.
- Stock, tailles, coloris, ordre, réglages, textes et commandes ne passent jamais par le build : le site les lit en direct.

### Ce qui manque
- **Manque** : le site ne relit la base qu'au chargement (`App.tsx` appelle `chargerDonnees` une seule fois).
- **Manque** : aucune Edge Function dans le projet (`supabase/functions/` n'existe pas). La suite de tests locale démarre sans leur runtime (`-x edge-runtime`), alors que `[edge_runtime] enabled = true` dans `config.toml`.
- **Manque** : l'ancien chemin de republication (robot → `republication_necessaire` → build hook) ne part jamais : le secret `NETLIFY_BUILD_HOOK` n'existe pas dans GitHub.
- Le lien envoyé dans le message WhatsApp d'une fiche est fabriqué à un seul endroit : `PageProduit.tsx`, `lienFiche` = `<site>/produit/<slug>`.
- Les photos de l'admin sont en WebP. L'image de partage doit être en JPEG (format sûr pour WhatsApp et Facebook) : aujourd'hui seul le build la fabrique, avec `sharp`.

### Netlify (sources du 2026-11-18)
- Offre gratuite : 300 crédits par mois, 15 crédits par mise en ligne en production, pas de dépassement facturé (le site se met en pause).

**À confirmer** : voir la section dédiée.

---

<a id="architecture"></a>
## Comment les morceaux s'emboîtent

```text
 /admin ── enregistre ──► Supabase : produits + photos (+ image de partage JPEG, lot 2.1)
                                 ▲                        ▲
                                 │ lit (clé publique)     │ lit
                                 │                        │
 WhatsApp / Facebook ──► Netlify : /p/<slug> ── relaie ──► Edge Function « apercu »
                                                            └─ renvoie : titre, prix, description,
                                                               image ; renvoie l'humain vers /produit/<slug>

 Google ──► Netlify : /sitemap.xml (écrit au build : pages fixes, types, collections)
                       └─ renvoie vers /sitemap-produits.xml ── relaie ──► Edge Function « sitemap-produits »
                                                                            └─ liste les pièces publiées, en direct

 Client sur le site ──► lit la base au chargement et au retour sur l'onglet (phase 1)
```

- **Aucun build pour le contenu.** Ce que l'admin change est lu en direct par le site et par les deux fonctions. Les builds restent pour le code.
- **Aucun secret.** Les deux fonctions lisent seulement des données déjà publiques (pièces publiées, photos publiques), avec la clé publique et les règles RLS actuelles.
- **Si une fonction tombe** : le site lui-même n'est pas touché. La vignette montre l'aperçu général de H MODE, et le robot de surveillance lève une alerte (lot 3.2).

---

<a id="phase-1"></a>
## Phase 1 — Le site ouvert suit l'admin

**Objectif** : un client qui a déjà le site ouvert voit le changement sans recharger.
**Résultat de phase** : on change un prix ou un stock dans l'admin, et un autre onglet du site affiche le nouveau contenu en quelques minutes, sans perdre un panier ni une saisie.

<a id="lot-1-1"></a>
### Lot 1.1 — Relire le catalogue pendant la visite

- **Objectif** : le site relit la base quand le client revient sur l'onglet, et au plus toutes les 5 minutes.
- **Pourquoi** : `chargerDonnees` ne tourne qu'une fois au chargement.
- **À faire**
  - Dans `lib/donnees.ts`, relancer la lecture sur `visibilitychange` (onglet redevenu visible), avec un délai minimum entre deux lectures.
  - Ne rien afficher de nouveau si le contenu est identique (déjà garanti par `appliquerDonnees`).
  - Test unitaire : lecture au retour d'onglet, pas de double lecture rapprochée, pas de remontage des pages à formulaire.
- **Dépend de** : rien.
- **Résultat attendu** : test vert ; dans le navigateur, un prix changé dans la base apparaît au retour sur l'onglet.
- **Décision nécessaire**
  - **Pourquoi la question se pose** : deux façons d'avoir de la mise à jour en direct chez le client.
  - **A — Relecture au retour d'onglet + toutes les 5 min** → aucun nouveau service, quelques requêtes de plus par visiteur. Le changement arrive en 5 minutes au pire.
  - **B — Supabase Realtime (poussé par la base)** → instantané, mais un service de plus à activer, une connexion `wss` côté client et des coupures à gérer.
  - **Avis technique** : A suffit pour un catalogue qui change peu.
- **Fait (2026-11-18)** : décision A. `lib/donnees.ts` : `suivreDonnees()` (branchée dans `App.tsx`) relit la base au retour sur l'onglet et toutes les 5 min s'il est visible, au plus une lecture par minute ; deux demandes simultanées partagent la même lecture. **En plus du prévu** : la fiche produit remettait couleur, taille et quantité à zéro à chaque nouvelle version des données ; elle garde maintenant le choix du visiteur tant qu'il est valable (`lib/selectionFiche.ts`). Preuves : `src/test/relecture.test.ts` (9 tests), 108 tests verts, types OK ; dans le navigateur sur la vraie base (lecture seule), retour immédiat = aucune lecture, retour une minute plus tard = une lecture, console sans erreur.

<a id="lot-1-2"></a>
### Lot 1.2 — Dire à l'admin quand c'est visible

- **Objectif** : après un enregistrement, l'admin lit un message exact sur ce que le client voit.
- **À faire**
  - Dans l'admin (`EditionProduit`, `Reglages`, `Textes`), compléter le message de succès : « Enregistré. Visible chez les clients tout de suite, et dans un site déjà ouvert sous 5 minutes. »
  - Vérification ordinateur et téléphone, jetons de design du thème admin.
- **Dépend de** : 1.1.
- **Résultat attendu** : le message s'affiche après chaque enregistrement et dit les mêmes délais que le code.
- **Fait (2026-11-18)** : phrase unique `VISIBILITE_CLIENTS` dans `lib/donnees.ts`, calculée depuis le délai du code, ajoutée aux messages de création, modification et suppression d'une pièce, des réglages et des textes. Tests de `admin-ecrans.test.tsx` mis à jour. **À vérifier** : l'affichage de la notification plus longue sur téléphone, au prochain passage dans l'admin local.

---

<a id="phase-2"></a>
## Phase 2 — Vignettes et plan du site à la demande

**Objectif** : la vignette d'un lien partagé et le plan du site pour Google suivent l'admin tout de suite, sans aucun build.
**Résultat de phase** : on crée une pièce dans l'admin ; son lien `/p/<slug>` partagé sur WhatsApp montre aussitôt son nom, son prix et sa photo, et elle figure dans le plan du site. Le compteur de builds Netlify n'a pas bougé.

<a id="lot-2-1"></a>
### Lot 2.1 — Image de partage fabriquée à l'enregistrement

- **Objectif** : chaque pièce a son image de partage JPEG 1200 × 630 dans Supabase Storage, fabriquée par l'admin, sans build.
- **Pourquoi** : les photos sont en WebP ; une Edge Function ne peut pas convertir les images simplement, et le build ne doit plus servir au contenu.
- **À faire**
  - Dans `features/admin/photos.ts`, ajouter la fabrication de l'image de partage dans le navigateur (canvas) : pièce entière sur le fond de la charte, monogramme en bas à droite, JPEG, moins de 300 Ko. Même rendu que `pages-partage.mjs`.
  - À l'enregistrement d'une pièce dont la première photo a changé (ou à la création), téléverser `partage/<slug>.jpg` dans le bucket `produits` (droits admin déjà en place).
  - ~~Script ponctuel pour les 62 pièces existantes~~ (**abandonné le 2026-11-21** : le build publie déjà `/partage/<slug>.jpg` pour chaque pièce, la fonction s'en sert en secours, voir lot 2.2).
  - Test unitaire : dimensions, format et poids de l'image produite.
- **Dépend de** : rien.
- **Résultat attendu** : après enregistrement d'une pièce dans l'admin local, `partage/<slug>.jpg` existe dans le stockage et s'ouvre en 1200 × 630.
- **Fait (2026-11-21)** :
  - `features/admin/photos.ts` : `fabriquerImagePartage` (canvas, fond `--fond`, pièce entière, monogramme, JPEG sous 290 Ko) et `cadrePartage` (placement testé). Monogramme public `public/images/marque/monogramme-168.png`, refait par `npm run logo`.
  - `api.ts` : `televerserImagePartage` (remplacement, cache 5 min) et `supprimerImagePartage`.
  - `EditionProduit.tsx` : image refaite **à chaque enregistrement** (pas seulement quand la première photo change : plus simple, et un échec se rattrape au prochain enregistrement) ; retirée si la pièce n'a plus de photo ou est supprimée. Un échec n'annule pas l'enregistrement (message d'information).
  - Migration `20261118120000_images_partage.sql` : JPEG accepté dans le bucket, **seulement** sous `partage/<slug>.jpg` ; remplacement réservé à l'admin.
  - Preuves : 111 tests verts (placement, envoi et retrait vérifiés dans `admin-ecrans.test.tsx`), types OK ; suite de la base locale verte avec le nouveau contrôle (client refusé, admin envoie et remplace, lecture publique, JPEG refusé hors de `partage/`) ; dans le navigateur, image réelle de la Air Force 1 : 1200 × 630, 79 Ko, pièce entière, monogramme présent.
  - Migration **pas encore en ligne** (lot 2.7).

<a id="lot-2-2"></a>
### Lot 2.2 — Edge Function `apercu` (vignette d'une pièce)

- **Objectif** : `/p/<slug>` renvoie une petite page avec les balises de partage de la pièce, lues dans la base au moment de la demande.
- **À faire**
  - Créer `supabase/functions/apercu/index.ts` : lit la pièce publiée par son `slug` avec la clé publique (règles RLS actuelles, aucune clé de service) ; renvoie une page HTML avec titre, description (prix + 140 caractères), image `partage/<slug>.jpg`, `og:url` = `/p/<slug>`, et une redirection sans script (`<meta http-equiv="refresh">` + lien) vers `/produit/<slug>` pour les humains.
  - Image, dans cet ordre : `partage/<slug>.jpg` du stockage (fabriquée par l'admin) ; sinon `<site>/partage/<slug>.jpg` (publiée par le build) ; sinon `<site>/partage/hmode.jpg` (image générale). Paramètre de version (`maj_le`) dans l'adresse pour que WhatsApp ne garde pas l'ancienne.
  - Pièce inconnue ou dépubliée : vignette générale de H MODE et redirection vers `/produit/<slug>` (le site affiche sa page 404).
  - Tout texte échappé ; `slug` vérifié par la même règle que la base ; `Cache-Control` court (5 min) pour limiter les appels.
  - `supabase/config.toml` : `[functions.apercu] verify_jwt = false` (appel anonyme par WhatsApp), avec un commentaire.
  - Test local (`supabase functions serve`) : pièce publiée → balises justes ; pièce dépubliée → vignette générale ; `slug` invalide → refus ; texte avec `<script>` → échappé.
- **Dépend de** : 2.1.
- **Résultat attendu** : le test local passe ; une modification de prix en base change la vignette au prochain appel, sans build.

<a id="lot-2-3"></a>
### Lot 2.3 — Edge Function `sitemap-produits`

- **Objectif** : la liste des pièces du plan du site vient de la base, en direct.
- **À faire**
  - Créer `supabase/functions/sitemap-produits/index.ts` : lit les `slug` publiés et renvoie un `sitemap.xml` de ces fiches (`/produit/<slug>`), avec `Cache-Control` d'une heure.
  - Dans `scripts/sitemap.mjs` : `sitemap.xml` devient un **index** qui pointe vers `sitemap-pages.xml` (pages fixes, types, collections, écrit au build comme aujourd'hui) et vers `/sitemap-produits.xml` (relayé vers la fonction). `robots.txt` reste inchangé.
  - Test : sans base, la fonction répond une liste vide valide ; avec une base locale, elle suit les ajouts et suppressions.
- **Dépend de** : rien.
- **Résultat attendu** : en local, une pièce ajoutée en base apparaît dans `sitemap-produits.xml` au prochain appel.

<a id="lot-2-4"></a>
### Lot 2.4 — Netlify relaie `/p/…` et le plan du site

- **Objectif** : les adresses `/p/<slug>` et `/sitemap-produits.xml` du site répondent par les deux fonctions.
- **À faire**
  - `web/public/_redirects` : `/p/*` et `/sitemap-produits.xml` relayés (statut 200) vers l'adresse des fonctions Supabase, placés avant les routes du site.
  - `infra/docker/nginx.conf` : même relais, pour garder la production locale identique (règle du projet).
  - `routes.test.ts` : vérifier que les deux relais existent dans les deux fichiers.
  - La politique CSP ne change pas : le relais se fait côté serveur, le navigateur ne voit que l'adresse du site.
- **Dépend de** : 2.2, 2.3.
- **Résultat attendu** : `routes.test.ts` vert ; en production locale Docker, `/p/<slug>` renvoie la vignette de la fonction locale.

<a id="lot-2-5"></a>
### Lot 2.5 — Le lien partagé devient `/p/<slug>`

- **Objectif** : le lien envoyé dans les messages WhatsApp mène à la vignette toujours à jour.
- **À faire**
  - `PageProduit.tsx` : `lienFiche` = `<site>/p/<slug>`.
  - Vérifier les autres endroits qui fabriquent un lien de fiche à partager (recherche dans `lib/whatsapp.ts` et `features/`).
  - Mettre à jour `whatsapp.test.ts` et `parcours.test.tsx`.
- **Dépend de** : 2.4.
- **Résultat attendu** : tests verts ; le message WhatsApp d'une fiche contient `/p/<slug>`, et ce lien ouvre la fiche normale.

<a id="lot-2-6"></a>
### Lot 2.6 — Retirer l'ancien chemin de republication

- **Objectif** : plus aucune trace d'un build lancé pour le contenu.
- **À faire**
  - `robot-sante.mjs` : supprimer l'appel à `republication_necessaire` et au build hook ; `sante.yml` : supprimer `NETLIFY_BUILD_HOOK`.
  - Migration : supprimer `republication_necessaire`. La table `republications` reste en lecture seule pour l'historique.
  - Admin : retirer l'affichage des dernières republications (`dernieresRepublications` dans `api.ts` et son écran).
  - Suite locale : retirer le test de `republication_necessaire`.
  - `pages-partage.mjs` reste : il garde à jour, à chaque mise en ligne de code, les aperçus des adresses `/produit/<slug>` copiées depuis la barre d'adresse.
- **Dépend de** : 2.5.
- **Résultat attendu** : plus aucune mention de build hook ; suite locale « Tout est vert ».

<a id="lot-2-7"></a>
### Lot 2.7 — Mise en service dans Supabase et Netlify

- **Objectif** : brancher la chaîne en ligne.
- **À faire** (dans cet ordre)
  1. **Sauvegarde** : `npm run sauvegarde`.
  2. Avec ton OK : `npx supabase functions deploy apercu` puis `npx supabase functions deploy sitemap-produits` (sans vérification de jeton, comme dans `config.toml`).
  3. Avec ton OK : `npx supabase db push --remote --dry-run`, puis `--yes` (migration du lot 2.6).
  4. ~~Script des images de partage des 62 pièces~~ (abandonné : secours sur les images du build, lot 2.2).
  5. Contrôle sans écriture : les deux fonctions répondent à leur adresse Supabase.
  6. PR `dev` → `main`, CI verte, fusion : **un seul build**, celui du code.
- **Dépend de** : 2.6.
- **Résultat attendu** : `/p/<slug>` et `/sitemap-produits.xml` répondent sur le site en ligne.

<a id="test-2"></a>
### Test réel de la phase 2

- **En local d'abord** : Supabase local avec le runtime des fonctions ; créer une pièce dans l'admin, ouvrir `/p/<slug>` et `/sitemap-produits.xml`, vérifier balises et image.
- **En ligne** (avec ton OK, un changement réversible) : changer le prix d'une pièce, coller `/p/<slug>` dans le débogueur de partage de Facebook et dans une discussion WhatsApp, vérifier le nouveau prix ; remettre le prix d'avant.
- **Compteur Netlify** : l'écran Usage ne montre aucun build pendant ces essais.

---

<a id="phase-3"></a>
## Phase 3 — Preuve et suivi

**Objectif** : la chaîne est testée de bout en bout et surveillée.
**Résultat de phase** : un test automatique garantit « admin change → client voit », et le robot prévient si les vignettes ou le plan du site tombent.

<a id="lot-3-1"></a>
### Lot 3.1 — Test automatique admin → client

- **Objectif** : un test Playwright prouve qu'un changement admin arrive chez un client.
- **À faire**
  - Dans `web/e2e/admin/` (Supabase local, compte admin jetable) : ouvrir le site client, changer le prix d'une pièce dans l'admin, revenir sur l'onglet client, vérifier le nouveau prix.
  - Remettre l'état d'avant à la fin, comme les tests existants.
- **Dépend de** : 1.1.
- **Résultat attendu** : `npm run test:e2e:admin` vert, avec ce nouveau test.

<a id="lot-3-2"></a>
### Lot 3.2 — Le robot surveille les vignettes et le plan du site

- **Objectif** : une panne des fonctions se voit dans Supervision et par e-mail.
- **À faire**
  - `robot-sante.mjs` : deux contrôles de plus, `/p/<slug d'une pièce publiée>` (balise `og:title` présente) et `/sitemap-produits.xml` (au moins une adresse).
  - Seuils de lenteur dans `seuil_lent_ms` pour ces deux cibles (migration).
  - Supervision affiche les deux nouvelles cibles comme les autres services.
- **Dépend de** : 2.7.
- **Résultat attendu** : au passage du robot suivant, les deux contrôles apparaissent dans Supervision en « opérationnel ».

<a id="lot-3-3"></a>
### Lot 3.3 — Décision écrite et plan du projet

- **Objectif** : la décision et l'état sont écrits.
- **À faire**
  - ADR `docs/decisions/0013-apercus-a-la-demande.md` : pourquoi plus aucun build pour le contenu (crédits Netlify), les deux fonctions, le lien `/p/<slug>`.
  - Note « revu par 0013 » dans l'ADR 0008 (republication par build).
  - Lot 47 dans `docs/projet/plan.md` ; mises à jour de `docs/architecture.md`, `CLAUDE.md` (commandes des fonctions, nouvelle route relayée), `supabase/README.md`, guide d'exploitation.
  - `.claude/skills/codebase-overview/SKILL.md` : nouveau dossier `supabase/functions/`.
- **Dépend de** : 2.7, 3.2.
- **Résultat attendu** : docs à jour et cohérentes avec le code.

---

<a id="actions"></a>
## Actions d'Oussama

| Quand | Action |
|---|---|
| Avant le lot 1.1 | ~~Choisir la relecture au retour d'onglet (A) ou Supabase Realtime (B).~~ **Fait** : A (2026-11-18). |
| Lot 2.7, étapes 2 et 3 | Donner ton OK pour déployer les deux fonctions et pousser les migrations (sauvegarde faite avant). |
| Lot 2.7, étape 6 | Valider la PR `dev` → `main`. |
| Test réel phase 2 | Donner ton OK pour un changement de prix réversible en ligne, puis vérifier toi-même la vignette dans WhatsApp. |
| Plus besoin | Créer un build hook Netlify ou un secret GitHub `NETLIFY_BUILD_HOOK`. |

---

<a id="a-confirmer"></a>
## Points à confirmer en cours de route

| Point | Quand | Pourquoi |
|---|---|---|
| WhatsApp et Facebook lisent bien les balises d'une page relayée par Netlify, et ne suivent pas la redirection avant de les lire | Test réel | Sinon ils liraient l'ancienne page de `/produit/<slug>` |
| Coût des requêtes relayées dans le quota de trafic Netlify | Avant 2.7 | Elles viennent des robots de partage seulement, mais le tarif exact n'est pas confirmé |
| Quota d'appels des Edge Functions de ton offre Supabase | Avant 2.7 | Fixe le `Cache-Control` raisonnable |
| ~~Bucket `produits` lisible publiquement pour `partage/<slug>.jpg`~~ | Lot 2.1 | **Confirmé** en local le 2026-11-21 (lecture publique 200) |
| Le relais Netlify garde-t-il le `Cache-Control` des fonctions ? | Lot 2.4 | Moins d'appels si Netlify garde la réponse en cache |

---

<a id="decide"></a>
## Décidé automatiquement

| Sujet | Choix | Pourquoi |
|---|---|---|
| Où ranger le plan | `docs/plans/` (dossier créé) | Le projet n'avait pas de dossier de plans ; `docs/projet/planning/` est l'historique d'octobre |
| Image de partage | Fabriquée dans le navigateur de l'admin, JPEG dans Storage | Une Edge Function convertit mal les images, et le build ne doit plus servir au contenu |
| Images des 62 pièces existantes | Pas de script : secours sur `/partage/<slug>.jpg` publié par le build | Aucune écriture en ligne, aucun accès admin depuis un script ; chaque pièce réenregistrée reçoit son image à jour |
| Adresse partagée | `/p/<slug>`, séparée de `/produit/<slug>` | La navigation normale ne passe pas par la fonction : les fiches restent aussi rapides |
| Plan du site | Index : pages fixes au build, pièces par la fonction | Types et collections ne sont pas en base ; les pièces, si |
| Clé utilisée par les fonctions | Clé publique + RLS existante, aucune clé de service | Elles ne lisent que des données publiques ; aucun secret à ranger |
| `pages-partage.mjs` | Gardé | Il couvre les adresses `/produit/<slug>` copiées depuis le navigateur, à chaque mise en ligne de code |
| Types et collections modifiables dans l'admin | Hors chantier | Pas demandé, et ça touche au schéma |
| Aucune écriture en ligne sans OK | Déploiements, migration, images et test réel après ton accord | Règle du projet |

---

<a id="zone-technique"></a>
## Zone technique concernée

- **Site client** : `web/src/lib/donnees.ts`, `web/src/lib/selectionFiche.ts` (nouveau), `web/src/App.tsx`, `web/src/features/produit/PageProduit.tsx` (`lienFiche`), `web/src/lib/whatsapp.ts`.
- **Admin** : `web/src/features/admin/photos.ts` (image de partage), `web/public/images/marque/monogramme-168.png`, `web/scripts/logo-marque.mjs`, `EditionProduit.tsx`, `Reglages.tsx`, `Textes.tsx`, `api.ts`, écran de Supervision.
- **Edge Functions (nouveau)** : `supabase/functions/apercu/index.ts`, `supabase/functions/sitemap-produits/index.ts`, `supabase/config.toml`.
- **Relais** : `web/public/_redirects`, `infra/docker/nginx.conf`.
- **Build** : `web/scripts/sitemap.mjs` (index), `web/scripts/pages-partage.mjs` (gardé), script ponctuel des images de partage.
- **Base** : `supabase/migrations/20261118120000_images_partage.sql` (lot 2.1), migration de retrait de `republication_necessaire` et des seuils du robot ; bucket `produits` (dossier `partage/`).
- **Robot** : `web/scripts/robot-sante.mjs`, `.github/workflows/sante.yml`.
- **Tests** : `web/src/test/` (`routes`, `whatsapp`, `parcours`, nouveaux tests), `web/scripts/tests-supabase-local.mjs`, `web/e2e/admin/`.
- **Docs** : `docs/projet/plan.md`, `docs/architecture.md`, `docs/README.md`, `docs/decisions/0008-…` (note), `docs/decisions/0013-…`, `CLAUDE.md`, `supabase/README.md`, `.claude/skills/codebase-overview/SKILL.md`.
