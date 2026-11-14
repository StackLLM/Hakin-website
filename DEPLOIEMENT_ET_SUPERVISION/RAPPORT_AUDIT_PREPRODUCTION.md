# Rapport d'audit avant mise en production — H MODE

- **Date des tests :** 14 novembre 2026
- **Ce qui a été testé :** le site public, la boutique, les comptes clients, l'administration, la base de données et la surveillance.
- **Objectif :** savoir si de vrais clients peuvent utiliser le site sans rencontrer de problème.

---

## 1. Le résumé en une minute

Le site fonctionne : toutes les pages s'ouvrent, et le parcours d'achat va jusqu'au bout, de la fiche produit à la commande enregistrée. La création de compte, la connexion, les favoris et l'administration fonctionnent aussi. Enfin, la base de données protège correctement les données de chaque client.

L'audit a trouvé **un problème important** et plusieurs petits. Ils sont tous corrigés et vérifiés, sauf un qui restait à régler dans Netlify (le badge, maintenant coupé).

**Le site n'est pas encore prêt à vendre en ligne**, mais la raison ne vient pas du code :

1. Les prix et les tailles ne sont pas encore saisis dans la base en ligne. Chaque pièce affiche donc « Prix sur demande », et personne ne peut commander directement par le site.
2. L'envoi d'e-mails (inscription, mot de passe oublié) n'est pas encore branché sur Brevo.

**Attention :** les corrections de cet audit sont sur la branche `dev` de ton ordinateur. Elles ne sont pas encore en ligne : le site public tourne toujours sur la version du 11 novembre (`0d81962`). Elles y arriveront quand `dev` sera poussée puis fusionnée dans `main`.

---

## 2. Comment les tests ont été faits

Trois environnements ont servi, pour ne jamais abîmer les vraies données :

| Environnement | À quoi il a servi | Pourquoi |
|---|---|---|
| **Base de données locale** (une copie de Supabase sur l'ordinateur) | Les vrais parcours : commander, créer un compte, se connecter, ajouter des favoris | On peut y passer de fausses commandes sans toucher à la vraie boutique |
| **Site en ligne** (hmodeclothes.netlify.app), en lecture seule | Vérifier ce que voit un vrai visiteur | Toute écriture dans la vraie base était bloquée pendant le test |
| **Production locale** (Docker, le même serveur que pour un hébergement à soi) | Vérifier le serveur web et ses réglages | C'est la version finale du site, construite comme en ligne |

Les tests ont été faits par un **vrai navigateur piloté automatiquement** (Chromium, avec Playwright). Il clique, remplit les formulaires et lit ce qui s'affiche, comme le ferait un client, puis relève chaque erreur.

Trois tailles d'écran ont été testées : **ordinateur** (1440 px), **tablette** (768 px) et **téléphone** (375 px).

---

## 3. Volet Front — ce que voit le client

Le « front », c'est tout ce qui s'affiche dans le navigateur : les pages, les boutons, les formulaires.

### 3.1 Toutes les pages s'ouvrent

**39 adresses** du site ont été ouvertes, chacune aux 3 tailles d'écran, soit 117 ouvertures :

- l'accueil ;
- la boutique : tous les rayons, Hommes, Femmes et Soldes ;
- la recherche, avec et sans résultat ;
- les fiches produit, y compris une fiche qui n'existe pas ;
- le panier, la commande et sa confirmation ;
- la connexion et le compte ;
- les pages d'information : contact, livraison, FAQ, guide des tailles, mentions légales, confidentialité, CGV ;
- une adresse inconnue.

**Résultat :**
- Chaque page affiche son titre principal.
- Une adresse inconnue affiche bien la page « Cette page s'est éclipsée » (page 404).
- Aucune image cassée n'a été trouvée.
- Aucune page ne déborde sur le côté, sur téléphone comme sur ordinateur.

### 3.2 Le parcours d'achat, du début à la fin

Le navigateur a joué le rôle d'un client, étape par étape :

| Étape | Ce qui a été fait | Résultat |
|---|---|---|
| Fiche produit | Clic sur « Ajouter au panier » sans choisir de taille | Le site refuse et affiche « Veuillez choisir une taille » ✅ |
| Fiche produit | Choix de la taille M, puis ajout | Le panier s'ouvre sur le côté avec la pièce ✅ |
| Fiche produit | Clic sur le cœur | La pièce passe en favori ✅ |
| Panier | Ajout d'un exemplaire (+1) | Le total passe à 1 040 DH, plus 30 DH de livraison, soit 1 070 DH ✅ (prix d'essai de la base locale) |
| Commande | Envoi du formulaire vide | Le site demande le nom ✅ |
| Commande | Téléphone incomplet (« 0612 ») | Le site demande un numéro marocain valide ✅ |
| Commande | Formulaire bien rempli, puis envoi | La commande est enregistrée dans la base, la page de confirmation s'affiche et le panier est vidé ✅ |
| Pièce sans prix | Clic sur « Demander prix et disponibilité » | Le message WhatsApp est prêt et la demande est notée pour l'administration ✅ |

### 3.3 Le compte client

| Ce qui a été testé | Résultat |
|---|---|
| Connexion avec un mauvais mot de passe | Refusée, avec le message « E-mail ou mot de passe incorrect » ✅ |
| Connexion avec le bon mot de passe | Le compte s'ouvre ✅ |
| Onglets Commandes, Adresses et Favoris | Les données du client s'affichent ✅ |
| Favori ajouté, puis page rechargée | Le favori est toujours là : il est enregistré dans la base ✅ |
| Déconnexion | Retour à la page de connexion ✅ |

### 3.4 Accessibilité

L'accessibilité permet à tout le monde d'utiliser le site, y compris au clavier seul ou avec un lecteur d'écran.

- Les tests automatiques (outil **axe**) passent sur les pages du site et sur les **14 écrans** de l'administration.
- Le site s'utilise **au clavier seul** : choisir une taille, ajouter au panier, passer commande, se connecter.
- Le score d'accessibilité Lighthouse est de **100** sur les pages principales.

### 3.5 Vitesse d'affichage (Lighthouse)

Lighthouse est l'outil de Google qui mesure la vitesse et la qualité d'une page. Note sur 100 :

| Page | Téléphone | Ordinateur |
|---|---|---|
| Accueil | 79 | 96 |
| Boutique | 77 | 96 |
| Fiche produit | 85 | 97 |
| Commande | 88 | 97 |
| Connexion | 99 | 100 |

Sur téléphone, l'accueil mettait **5 secondes** à afficher sa grande photo, sur la connexion lente simulée par Google. La cause : la photo était chargée sans priorité. Elle est maintenant prioritaire (voir la partie 7).

Le SEO, c'est-à-dire la façon dont Google lit la page, est à 100 sur les pages publiques. Il est à 63 sur Commande et Connexion parce que ces pages sont **volontairement cachées à Google**. C'est normal.

---

## 4. Volet Backend — la base de données

Le « backend », c'est la partie invisible pour le client. Ici, c'est la base de données Supabase, qui garde les produits, les commandes, les comptes et les réglages.

### 4.1 Les tests de la base (base locale)

Une série de tests a vérifié les règles de sécurité de la base. **Tout est vert.**

- **Chaque client ne voit que ses propres données.** Un second compte sur le même appareil ne voit rien du premier.
- **Un client ne peut pas modifier ce qui ne lui appartient pas.** La base refuse avec le code `42501`, qui veut dire « accès interdit ».
- **Le prix d'une commande est pris dans la base**, jamais dans le navigateur. Un client ne peut donc pas changer le prix lui-même.
- **Une demande WhatsApp ne crée jamais de commande.**
- **Les droits d'administration sont vérifiés par la base**, et un droit retiré prend effet tout de suite.
- **Le compte administrateur** se crée sans inscription publique. Ni le mot de passe ni la clé de sécurité n'apparaissent en clair.

### 4.2 L'administration (`/admin`)

L'administration a été testée dans un vrai navigateur, avec un compte administrateur jetable :

| Ce qui a été testé | Résultat |
|---|---|
| Créer une pièce dans l'administration, puis la faire commander par un client | La commande arrive dans l'administration ✅ |
| Mauvaise clé de sécurité, puis mauvais mot de passe | Refusés ✅ |
| Accessibilité des 14 écrans | Aucun défaut ✅ |
| Téléphone 375 px | Aucun débordement ; le menu s'ouvre en tiroir, la recherche Ctrl+K marche ✅ |

---

## 5. Volet API — les échanges entre le site et la base

L'API est la porte par laquelle le site parle à la base. Chaque action du client envoie une demande, et la base répond par un code. 200, 201 et 204 veulent dire « réussi » ; 400 veut dire « refusé » ; 429 veut dire « trop de demandes ».

Voici les demandes relevées pendant les parcours sur la base locale :

| Action du client | Demande envoyée | Réponse |
|---|---|---|
| Passer une commande | `passer_commande` | 200 — commande enregistrée ✅ |
| Demander un prix sur WhatsApp | `noter_demande_whatsapp` | 204 — demande notée ✅ |
| Se connecter avec un mauvais mot de passe | connexion | 400 — refusé ✅ |
| Se connecter avec le bon mot de passe | connexion | 200 ✅ |
| Ouvrir son compte | profil, favoris, panier, adresses, commandes | 200 pour chacun ✅ |
| Ajouter un favori | favoris | 201 — enregistré ✅ |
| Ouvrir n'importe quelle page | catalogue et réglages | 200 ✅ |

**La protection anti-abus fonctionne.** Le test a ouvert plus de 100 pages en quelques minutes depuis le même navigateur. Le compteur de visites a alors répondu **429** (« trop de demandes ») au lieu de planter. C'est le comportement prévu : un robot ne peut pas inonder la base.

---

## 6. Volet Santé — sécurité, surveillance et hébergement

### 6.1 Le site en ligne

| Ce qui a été vérifié | Résultat |
|---|---|
| Les pages répondent | Oui ✅ |
| Une adresse inconnue renvoie bien une erreur 404 | Oui ✅ |
| Le fichier `robots.txt` cache à Google les pages privées (compte, panier, commande, admin) | Oui ✅ |
| Le plan du site pour Google (`sitemap.xml`) existe | Oui ✅ |
| Le fichier de version (`version.json`) indique quelle version est en ligne | Oui ✅ |

### 6.2 Les protections de sécurité du site

Ce sont des réglages envoyés par le serveur avec chaque page. Tous sont en place :

| Protection | À quoi elle sert |
|---|---|
| **CSP** (Content Security Policy) | N'autorise que les scripts du site lui-même et la base Supabase. Un script étranger est bloqué |
| **HSTS** | Force la connexion sécurisée (https) |
| **X-Frame-Options** | Empêche un autre site d'afficher H MODE à l'intérieur du sien, une technique d'arnaque |
| **X-Content-Type-Options** | Empêche le navigateur de deviner le type d'un fichier |
| **Referrer-Policy** | Limite ce qui est transmis aux autres sites quand on clique un lien |
| **Permissions-Policy** | Coupe la caméra, le micro, la position et le paiement, que le site n'utilise pas |

La CSP a d'ailleurs prouvé son utilité : elle bloquait le script du badge Netlify, qui n'était pas prévu. Le badge est maintenant coupé, et le script n'est plus injecté (vérifié).

### 6.3 La surveillance automatique

- **Le robot GitHub** contrôle le site toutes les 30 minutes : pages, version, page 404, base, comptes et WhatsApp. Son premier passage a réussi **9 contrôles sur 9**, et ses résultats s'affichent dans Admin → Supervision.
- **Les sondes externes (UptimeRobot)** seront installées après l'achat du nom de domaine.

### 6.4 La production locale (Docker)

Le site a aussi été construit et lancé comme sur un serveur à soi :

- le point de santé `/sante` répond 200 ;
- une adresse inconnue renvoie 404 ;
- une fiche partagée s'ouvre directement avec son titre ;
- la console du navigateur ne montre aucune erreur.

---

## 7. Les problèmes trouvés et leur correction

| Gravité | Problème | Ce que ça faisait au client | Correction | Vérifié |
|---|---|---|---|---|
| **Haute** | Quand la base répondait, une à deux secondes après l'ouverture, la fiche produit se réaffichait entièrement, même si rien n'avait changé | Le client perdait la taille et la quantité qu'il venait de choisir | La page ne se réaffiche plus si les données reçues sont les mêmes | La taille choisie reste cochée ✅ |
| Moyenne | Toutes les pages portaient le même titre d'onglet, sauf la fiche, dont le titre restait affiché ensuite | Onglets trompeurs, mauvais pour Google et pour les lecteurs d'écran | Chaque page a son propre titre, par exemple « Dior — T-shirt logo Dior · H MODE » | Testé sur 9 pages ✅ |
| Moyenne | Le lien rouge « Soldes » était affiché alors qu'aucune pièce n'est en solde | Le client tombait sur une page vide | « Soldes » n'apparaît que s'il y a au moins une pièce en solde | Test automatique ajouté ✅ |
| Moyenne | Netlify injectait le script de son badge, bloqué par la CSP | Une erreur dans la console à chaque page | Badge coupé dans Netlify | Script absent du site en ligne ✅ |
| Basse | Un lien de fiche partagé faisait un détour (`/produit/x` redirigé vers `/produit/x/`) | Un chargement de plus | Les pages de partage sont rangées autrement, sans redirection | Production locale : réponse directe ✅ ; à revérifier en ligne après fusion |
| Basse | La grande photo de l'accueil n'était pas chargée en priorité | Accueil lent sur téléphone (5 s) | La photo est chargée en premier | Elle part au bout de 0,1 s ✅ |
| Basse | Avertissements du routeur React dans la console, aussi en ligne | Bruit qui cache les vraies erreurs | Réglage du routeur mis à jour | Console vide ✅ |
| Basse | Le compteur de visites continuait d'envoyer après un refus 429 | Demandes inutiles | Il s'arrête après un refus | Testé ✅ |

---

## 8. Qualité du code

### Ce qui est solide
- **Un seul accès à la base**, regroupé à un endroit. Le site reste utilisable même si la base est injoignable.
- **Les droits sont vérifiés par la base**, jamais par le navigateur, qui pourrait être trafiqué.
- **Aucun secret dans le site** : seules l'adresse et la clé publique de Supabase y figurent.
- **Chaque écriture publique est limitée** contre les abus (code 429).
- **Les adresses des pages sont cohérentes** entre l'application, Netlify et le serveur Docker.
- Aucun message de débogage oublié, aucune erreur ignorée en silence, aucune insertion de HTML brut.

### Ce qui a été nettoyé
- Six fonctions jamais utilisées ont été retirées de `lib/utils.ts`, dont un format de prix en dollars contraire à la règle des prix en DH.
- Une ombre écrite en dur est passée dans les couleurs officielles (`--ombre-photo-type`).
- Un outil des tests de vitesse (`chrome-launcher`) est maintenant déclaré dans le projet au lieu d'arriver par hasard.

### Ce qui reste (sans urgence)
- Le code chargé au démarrage pèse **149 Ko compressés**. C'est correct, mais il pourrait être allégé plus tard.
- Une quinzaine de petites fonctions sont exportées sans être utilisées. Les retirer n'apporte presque rien.
- Un avertissement de la bibliothèque d'animation (framer-motion) apparaît en développement seulement, jamais en ligne.

---

## 9. Résultats de tous les tests

| Contrôle | Ce qu'il vérifie | Résultat |
|---|---|---|
| Types (TypeScript) | Le code est cohérent avec lui-même | ✅ |
| Tests unitaires (Vitest) | La logique : panier, filtres, commande, compte, titres… | ✅ 98 sur 98 |
| Navigateur, site (Playwright) | Parcours d'achat, clavier, accessibilité, menu | ✅ 44 réussis, 14 ignorés (prévus pour l'autre taille d'écran) |
| Navigateur, administration (Playwright) | Création d'une pièce jusqu'à sa commande, accessibilité, mobile | ✅ 4 sur 4 |
| Base locale | Comptes, droits, administration, demandes | ✅ tout vert |
| Build de production | Le site se construit sans erreur | ✅ |
| Synchronisation de la charte (CloneMe) | Les couleurs du code suivent `palette.md` | ✅ aucun écart |

---

## 10. Ce qui n'a pas été testé, et pourquoi

| Point | Raison |
|---|---|
| L'ouverture réelle de WhatsApp | Simulée pendant les tests, sinon un vrai message serait parti à chaque essai. Le lien et son texte ont, eux, été vérifiés |
| Les e-mails d'inscription et de mot de passe oublié | L'envoi d'e-mails (Brevo) n'est pas encore branché |
| Une commande sur la vraie base | Volontaire : ne pas créer de fausse commande dans la vraie boutique |
| Le détour des fiches partagées, sur Netlify | Les corrections ne sont pas encore en ligne |

---

## 11. Avant d'ouvrir aux clients

| # | Action | Qui | Bloquant ? |
|---|---|---|---|
| 1 | Saisir les **prix et les tailles** dans `/admin` | La boutique | **Oui** : sans prix, aucune commande directe |
| 2 | Brancher l'envoi d'**e-mails (Brevo)** | Toi | **Oui** pour les comptes clients |
| 3 | Pousser `dev`, ouvrir la demande de fusion vers `main` et attendre la CI verte | Toi | Oui, pour mettre en ligne les corrections de cet audit |
| 4 | Après la fusion, vérifier que `curl -sI https://hmodeclothes.netlify.app/produit/t-shirt-prada-graffiti` répond `200` | Toi | Non |
| 5 | Acheter le **nom de domaine** | Toi | Non, mais recommandé |
| 6 | Installer **UptimeRobot** sur le nouveau domaine | Toi | Non |

---

## 12. Verdict

**Le code est prêt pour la production.** Les parcours importants ont été testés pour de vrai et marchent, la sécurité de la base tient, et les problèmes trouvés sont corrigés et vérifiés.

**La boutique, elle, n'est pas encore prête à vendre en ligne.** Il manque les prix et l'envoi d'e-mails. Dès que ces deux points sont faits, et les corrections fusionnées dans `main`, le site peut accueillir de vrais clients.
