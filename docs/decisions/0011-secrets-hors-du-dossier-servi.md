# 0011 — Aucun secret dans le dossier servi par Vite ; serveur de développement en localhost
- Date : 2026-11-15
- Contexte : l'audit de sécurité du 15/11 a montré que le serveur de développement (port 6013) écoutait tout le réseau
  local (`host: true`) avec Vite 5.4.11, qui laisse lire `.env` en ajoutant `?raw??` à l'adresse et autorise n'importe
  quel site à lire ses réponses. Or `web/.env` contenait les accès de l'administration (`ADMIN_EMAIL`,
  `ADMIN_MOT_DE_PASSE`, `ADMIN_CLE`) et le jeton du robot (`SANTE_JETON`). Une personne sur le même Wi-Fi pouvait donc
  les lire, puis ouvrir `/admin` en ligne. Vérifié sur une copie jetable de Vite, avec un faux `.env`.
- Décisions :
  - **Vite à jour** (5.4.21) et **serveur de développement en `localhost`** seulement. Pour tester sur un téléphone :
    `npx vite --host`, ponctuellement, puis l'arrêter.
  - **`web/` ne contient aucun secret.** `web/.env` ne garde que `VITE_SUPABASE_URL` et `VITE_SUPABASE_PUBLISHABLE_KEY`,
    déjà publiques dans le site. Les accès admin et `SANTE_JETON` vivent dans **`.env.admin` à la racine** (droits 600,
    ignoré par Git, modèle `.env.admin.example`). `admin:sql`, `sante:sql`, `sauvegarde` et `sauvegarde:tester` lisent
    les deux fichiers (`--env-file-if-exists`, le second complète le premier).
  - `server.fs.deny` reprend la liste par défaut de Vite et ajoute `**/rapports/**` (comptes de test, résultats).
  - Les fichiers générés qui contiennent une empreinte d'accès (SQL d'`admin:sql`) ne restent pas dans le projet.
  - Mot de passe, clé admin et jeton du robot **non changés** (choix de l'utilisateur, aucun signe d'accès).
- Conséquences :
  - Une nouvelle variable secrète va dans `.env.admin`, jamais dans `web/.env`, et jamais avec le préfixe `VITE_`.
  - Avant de rallumer le 6013 sur le réseau, vérifier que Vite est à jour (`npm audit`).
  - Si un doute apparaît un jour sur une fuite : changer les trois valeurs admin (`npm run admin:sql`) et le jeton du
    robot (`npm run sante:sql`, puis le secret GitHub).
