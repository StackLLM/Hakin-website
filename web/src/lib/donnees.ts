import { create } from 'zustand'
import { signalerErreur } from '@/lib/supervision'
import { obtenirSupabase } from '@/lib/supabase'
import { appliquerCatalogue, appliquerReglages } from '@/lib/catalogue'
import { ligneVersProduit, type LigneProduit, type Textes } from '@/lib/produitsBase'
import type { ReglagesBoutique, Produit } from '@/lib/types'

/** Origine des données affichées : fichiers livrés avec le site, dernière copie de la base gardée sur l'appareil, ou la base. */
export type SourceDonnees = 'fichier' | 'copie' | 'base'
interface EtatDonnees { version: number; source: SourceDonnees }
/** `version` change à chaque nouveau catalogue appliqué : l'appli s'en sert pour réafficher les pages. */
export const useDonnees = create<EtatDonnees>(() => ({ version: 0, source: 'fichier' }))

const CLE_COPIE = 'hmode-catalogue'
interface Copie { v: 1; produits: Produit[]; boutique: ReglagesBoutique | null; textes: Partial<Textes> | null }

let dernierContenu: string | null = null

/** Applique un catalogue. Contenu identique au dernier appliqué (cas courant : la base répond la même chose que la
 *  copie de l'appareil) : `version` ne bouge pas, sinon la page se remonterait et le visiteur perdrait sa taille,
 *  sa quantité ou son message d'erreur. Exporté pour les tests. */
export function appliquerDonnees(c: Omit<Copie, 'v'>, source: SourceDonnees) {
  const contenu = JSON.stringify([c.produits, c.boutique, c.textes])
  if (contenu === dernierContenu) { if (useDonnees.getState().source !== source) useDonnees.setState({ source }); return }
  dernierContenu = contenu
  if (c.produits.length) appliquerCatalogue(c.produits)
  appliquerReglages(c.boutique, c.textes)
  useDonnees.setState(s => ({ version: s.version + 1, source }))
}

/** Relecture pendant la visite (lot 47, phase 1) : au retour sur l'onglet, et toutes les 5 min tant qu'il est visible.
 *  Un client qui a déjà le site ouvert voit donc un changement de l'admin sous 5 min au plus. */
export const RELECTURE_PERIODE_MS = 5 * 60_000
/** Écart minimum entre deux lectures : aller-retour rapide entre onglets = une seule lecture. */
export const RELECTURE_ECART_MIN_MS = 60_000
/** Phrase commune des messages de l'admin après un enregistrement (même délai que le code). */
export const VISIBILITE_CLIENTS = `Visible sur le site tout de suite, et sous ${RELECTURE_PERIODE_MS / 60_000} min chez un client qui l'a déjà ouvert.`

let derniereLecture = 0
let lectureEnCours: Promise<void> | null = null

/** Lit la base et applique le résultat. Deux appels simultanés partagent la même lecture.
 *  Base vide ou injoignable : on garde ce qu'on a (fichiers ou copie). Jamais d'écran vide. */
function lireBase(): Promise<void> {
  if (lectureEnCours) return lectureEnCours
  derniereLecture = Date.now()
  lectureEnCours = (async () => {
    const sb = await obtenirSupabase()
    if (!sb) return
    try {
      const [rProduits, rReglages] = await Promise.all([
        sb.from('produits').select('*').eq('publie', true).order('ordre').order('nom'),
        sb.from('reglages').select('cle, valeur'),
      ])
      if (rProduits.error || rReglages.error) throw rProduits.error ?? rReglages.error
      const produits = ((rProduits.data ?? []) as LigneProduit[]).map(l => {
        const { publie: _p, ordre: _o, ...p } = ligneVersProduit(l)
        return p as Produit
      })
      const reglages = Object.fromEntries(((rReglages.data ?? []) as { cle: string; valeur: unknown }[]).map(r => [r.cle, r.valeur]))
      const c = { produits, boutique: (reglages.boutique ?? null) as ReglagesBoutique | null, textes: (reglages.textes ?? null) as Partial<Textes> | null }
      appliquerDonnees(c, 'base')
      try { localStorage.setItem(CLE_COPIE, JSON.stringify({ v: 1, ...c })) } catch { /* stockage plein ou bloqué */ }
    } catch (e) {
      console.warn('[catalogue] base injoignable, données locales gardées :', e)
      signalerErreur('api', `Catalogue : base injoignable (${String((e as Error)?.message ?? e)})`, { gravite: 'avertissement' })
    }
  })().finally(() => { lectureEnCours = null })
  return lectureEnCours
}

/** Au démarrage : reprend la dernière copie de la base (affichage immédiat), puis lit la base.
 *  Aussi appelée par l'admin après un enregistrement (lecture immédiate, sans écart minimum). */
export async function chargerDonnees() {
  try {
    const brut = localStorage.getItem(CLE_COPIE)
    const copie = brut ? JSON.parse(brut) as Copie : null
    if (copie?.v === 1 && Array.isArray(copie.produits)) appliquerDonnees(copie, 'copie')
  } catch { /* copie illisible : ignorée */ }
  await lireBase()
}

/** Relit la base si la dernière lecture date d'au moins `ecartMin` ms. */
export function relireDonnees(ecartMin = RELECTURE_ECART_MIN_MS): Promise<void> {
  return Date.now() - derniereLecture < ecartMin ? Promise.resolve() : lireBase()
}

/** Branche la relecture pendant la visite. Renvoie la fonction qui l'arrête (démontage de l'application). */
export function suivreDonnees(): () => void {
  const visible = () => document.visibilityState === 'visible'
  const surVisibilite = () => { if (visible()) void relireDonnees() }
  const minuterie = window.setInterval(() => { if (visible()) void relireDonnees() }, RELECTURE_PERIODE_MS)
  document.addEventListener('visibilitychange', surVisibilite)
  return () => { window.clearInterval(minuterie); document.removeEventListener('visibilitychange', surVisibilite) }
}
