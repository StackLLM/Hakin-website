# Documentation de H MODE

| Je veux… | Lire |
|---|---|
| Lancer le projet, les commandes | [`../README.md`](../README.md) |
| Mettre en ligne, surveiller, sauvegarder, connaître les coûts | [guide PDF](../DEPLOIEMENT_ET_SUPERVISION/GUIDE_DEPLOIEMENT_HEBERGEMENT_MAINTENANCE_HMODE.pdf) et [`../DEPLOIEMENT_ET_SUPERVISION/`](../DEPLOIEMENT_ET_SUPERVISION/) (étude, supervision, checklist, [rapport d'audit avant production](../DEPLOIEMENT_ET_SUPERVISION/RAPPORT_AUDIT_PREPRODUCTION.md)) ; source du PDF : [`guide-pdf/`](guide-pdf/) |
| Lancer la boutique sur Instagram, Facebook et TikTok : prix de la publicité au Maroc, trois offres, budget | [guide PDF marketing](../MARKETING_ET_LANCEMENT/GUIDE_LANCEMENT_MARKETING_HMODE.pdf) ; source : [`guide-marketing-pdf/`](guide-marketing-pdf/) ; fiches par réseau : [`../marketing/`](../marketing/INDEX.md) |
| Lancer la marque sur les réseaux (identité, prompts, stratégies, publicité) | [`../marketing/INDEX.md`](../marketing/INDEX.md) |
| Comprendre comment le site est construit | [`architecture.md`](architecture.md) |
| Savoir pourquoi un choix a été fait | [`decisions/`](decisions/) (ADR, ci-dessous) |
| Voir où en est le projet, lot par lot | [`projet/plan.md`](projet/plan.md) (tableau « Avancement » en haut) |
| Savoir ce qui reste à faire ou à fournir | [`projet/TODO.md`](projet/TODO.md) |
| Modifier l'apparence (pages, couleurs, animations) | [`../web/design.md`](../web/design.md), [`../web/palette.md`](../web/palette.md), [`../web/animation.md`](../web/animation.md) |
| Faire évoluer la base | [`../supabase/README.md`](../supabase/README.md) |
| Ajouter ou remplacer des photos | [`../web/medias/LISEZMOI.md`](../web/medias/LISEZMOI.md) |

## Décisions (ADR)

| N° | Décision | État |
|---|---|---|
| [0001](decisions/0001-commande-whatsapp-sans-backend.md) | Commande par WhatsApp, paiement à la livraison | en vigueur ; « sans backend » remplacé par 0005 |
| [0002](decisions/0002-prix-sur-demande-et-mode-demo.md) | Prix « sur demande » tant qu'ils ne sont pas saisis | en vigueur ; mode démo supprimé le 04/11 |
| [0003](decisions/0003-methode-ui-stealer-charte-hmode.md) | Méthode UI Stealer, charte H MODE | en vigueur ; mise en page refaite par CloneMe (lot 15) |
| 0004 | — | numéro non utilisé |
| [0005](decisions/0005-supabase-comptes-commandes.md) | Supabase pour comptes, panier et commandes | en vigueur |
| [0006](decisions/0006-administration.md) | Administration `/admin` à trois champs, droits vérifiés par la base | en vigueur |
| [0007](decisions/0007-architecture-et-deploiement.md) | Un seul site statique + Supabase, dépôt rangé, CI/CD | en vigueur |
| [0008](decisions/0008-supervision-et-commerce.md) | Supervision sans serveur, rôles admin, limites, demandes WhatsApp, aperçus de partage | en vigueur ; complétée par 0009 |
| [0009](decisions/0009-sante-429-journal.md) | Point de santé public, réponses 429, journal unifié, sauvegardes testées par script, guide PDF | en vigueur ; écrans revus par 0010, plafond des commandes revu par 0012 |
| [0010](decisions/0010-admin-application-technique.md) | Administration en application technique : thème propre, composants Lightswind, supervision en 5 pages | en vigueur |
| [0011](decisions/0011-secrets-hors-du-dossier-servi.md) | Aucun secret dans `web/` (accès admin et jeton du robot dans `.env.admin`), serveur de dev en localhost, Vite à jour | en vigueur |
| [0012](decisions/0012-afflux-de-commandes.md) | Un afflux de commandes ne bloque plus les clients (commande « à vérifier ») ; empreinte du visiteur fiable | en vigueur ; complète 0009 |

Nouvelle décision : copier [`decisions/0000-modele.md`](decisions/0000-modele.md) avec le numéro suivant.

## Autres dossiers

- [`design/`](design/) : rapport de clonage Original Fit, maquettes d'origine, ancien prompt du logo (remplacé).
- [`projet/planning/`](projet/planning/) : roadmap et plans de cadrage d'octobre 2026 (historique, non tenus à jour).
