import { trouverCategorie, trouverCollection, trouverProduit } from '@/lib/catalogue'

/** Titre de l'onglet par défaut : le même que `index.html` et la page d'accueil partagée (`scripts/pages-partage.mjs`). */
export const TITRE_SITE = 'H MODE — Boutique premium · Casablanca'

const PAGES: Record<string, string> = {
  '/boutique': 'Boutique',
  '/collections': 'Collections',
  '/recherche': 'Recherche',
  '/panier': 'Panier',
  '/commande': 'Commande',
  '/commande/confirmation': 'Commande envoyée',
  '/connexion': 'Connexion',
  '/connexion/nouveau-mot-de-passe': 'Nouveau mot de passe',
  '/contact': 'Contact',
  '/maison': 'La Maison',
  '/livraison-retours': 'Livraison & retours',
  '/faq': 'Questions fréquentes',
  '/guide-des-tailles': 'Guide des tailles',
  '/mentions-legales': 'Mentions légales',
  '/confidentialite': 'Confidentialité',
  '/cgv': 'Conditions générales de vente',
}

const avecMarque = (t: string) => `${t} · H MODE`

/** Titre de l'onglet pour une adresse du site (WCAG 2.4.2). Fiche : « Marque — Nom · H MODE », comme sa page partagée.
 *  Adresse inconnue : « Page introuvable ». Lu dans le catalogue courant (base ou fichiers). */
export function titrePage(pathname: string, search = ''): string {
  const chemin = pathname.length > 1 ? pathname.replace(/\/+$/, '') : pathname
  if (chemin === '/') return TITRE_SITE
  const [, racine, cle] = chemin.split('/')
  if (racine === 'produit' && cle) {
    const p = trouverProduit(decodeURIComponent(cle))
    return avecMarque(p ? `${p.marque} — ${p.nom}` : 'Page introuvable')
  }
  if (racine === 'boutique') {
    if (cle) {
      const c = trouverCategorie(decodeURIComponent(cle))
      return avecMarque(c ? c.nom : 'Page introuvable')
    }
    const sp = new URLSearchParams(search)
    if (sp.get('solde') === '1') return avecMarque('Soldes')
    if (sp.get('genre') === 'homme') return avecMarque('Hommes')
    if (sp.get('genre') === 'femme') return avecMarque('Femmes')
    return avecMarque('Boutique')
  }
  if (racine === 'collections' && cle) {
    const c = trouverCollection(decodeURIComponent(cle))
    return avecMarque(c ? c.nom : 'Page introuvable')
  }
  if (racine === 'compte') return avecMarque('Mon compte')
  if (racine === 'admin') return avecMarque('Administration')
  return avecMarque(PAGES[chemin] ?? 'Page introuvable')
}
