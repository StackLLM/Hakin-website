import type { Produit } from '@/lib/types'

/** Choix du visiteur sur une fiche produit. */
export interface SelectionFiche { coloris: string | null; taille: string | null; quantite: number }

/** Dernier choix fait sur une fiche (une seule fiche retenue). La relecture de la base (lib/donnees.ts) remonte la page
 *  quand le catalogue change : sans cette mémoire, le visiteur perdrait sa couleur, sa taille et sa quantité. */
let derniere: { slug: string; selection: SelectionFiche } | null = null

export const lireSelection = (slug: string): SelectionFiche | undefined => (derniere?.slug === slug ? derniere.selection : undefined)
export function noterSelection(slug: string, selection: SelectionFiche) { derniere = { slug, selection } }

/** Choix à afficher pour une pièce : le précédent tant qu'il existe encore (coloris présent, taille présente et
 *  disponible), sinon les valeurs de départ (premier coloris, aucune taille, quantité 1). */
export function selectionValide(p: Produit, avant?: SelectionFiche): SelectionFiche {
  const coloris = avant?.coloris && p.coloris.some(c => c.nom === avant.coloris) ? avant.coloris : p.coloris[0]?.nom ?? null
  const taille = avant?.taille && p.tailles.some(t => t.taille === avant.taille && t.disponible) ? avant.taille : null
  return { coloris, taille, quantite: avant?.quantite ?? 1 }
}
