import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import type { Produit } from '@/lib/types'

// Fausse base : compte les lectures du catalogue et renvoie des textes réglables (pour faire changer le contenu).
const base = vi.hoisted(() => ({ lectures: 0, textes: { accroche: 'v1' } as Record<string, string> }))
vi.mock('@/lib/supervision', () => ({ signalerErreur: vi.fn() }))
vi.mock('@/lib/supabase', () => ({
  obtenirSupabase: async () => ({
    from: (table: string) => {
      if (table === 'produits') base.lectures++
      const reponse = Promise.resolve({ data: table === 'produits' ? [] : [{ cle: 'textes', valeur: base.textes }], error: null })
      const requete: Record<string, unknown> = {}
      for (const m of ['select', 'eq', 'order']) requete[m] = () => requete
      requete.then = reponse.then.bind(reponse)
      return requete
    },
  }),
}))

const { chargerDonnees, relireDonnees, suivreDonnees, useDonnees, RELECTURE_PERIODE_MS, RELECTURE_ECART_MIN_MS } = await import('@/lib/donnees')
const { selectionValide, lireSelection, noterSelection } = await import('@/lib/selectionFiche')

let visible = true
Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => (visible ? 'visible' : 'hidden') })
const changerVisibilite = (v: boolean) => { visible = v; document.dispatchEvent(new Event('visibilitychange')) }

describe('relecture de la base pendant la visite', () => {
  let arreter = () => {}
  beforeEach(async () => {
    vi.useFakeTimers()
    vi.setSystemTime(new Date('2026-11-18T10:00:00Z'))
    visible = true
    await chargerDonnees()
    base.lectures = 0
    arreter = suivreDonnees()
  })
  afterEach(() => { arreter(); vi.useRealTimers() })

  it('retour sur l\'onglet : une lecture, mais pas deux à moins d\'une minute d\'écart', async () => {
    await vi.advanceTimersByTimeAsync(RELECTURE_ECART_MIN_MS)
    changerVisibilite(false); changerVisibilite(true)
    await vi.advanceTimersByTimeAsync(0)
    expect(base.lectures).toBe(1)
    changerVisibilite(false); changerVisibilite(true)
    await vi.advanceTimersByTimeAsync(0)
    expect(base.lectures).toBe(1)
  })

  it('toutes les 5 min tant que l\'onglet est visible, jamais quand il est caché', async () => {
    await vi.advanceTimersByTimeAsync(RELECTURE_PERIODE_MS)
    expect(base.lectures).toBe(1)
    visible = false
    await vi.advanceTimersByTimeAsync(RELECTURE_PERIODE_MS * 2)
    expect(base.lectures).toBe(1)
  })

  it('contenu changé dans la base : nouvelle version ; contenu identique : la version ne bouge pas', async () => {
    const v = useDonnees.getState().version
    await vi.advanceTimersByTimeAsync(RELECTURE_PERIODE_MS)
    expect(useDonnees.getState().version).toBe(v)
    base.textes = { accroche: `v${Date.now()}` }
    await vi.advanceTimersByTimeAsync(RELECTURE_PERIODE_MS)
    expect(useDonnees.getState().version).toBe(v + 1)
  })

  it('deux demandes en même temps : une seule lecture', async () => {
    await vi.advanceTimersByTimeAsync(RELECTURE_ECART_MIN_MS)
    await Promise.all([relireDonnees(), relireDonnees(0)])
    expect(base.lectures).toBe(1)
  })

  it('arrêtée : plus aucune lecture', async () => {
    arreter()
    await vi.advanceTimersByTimeAsync(RELECTURE_PERIODE_MS * 3)
    changerVisibilite(false); changerVisibilite(true)
    await vi.advanceTimersByTimeAsync(0)
    expect(base.lectures).toBe(0)
  })
})

describe('choix du visiteur gardé sur la fiche quand les données changent', () => {
  const piece = {
    slug: 'essai', coloris: [{ nom: 'Noir', hex: '#000' }, { nom: 'Blanc', hex: '#fff' }],
    tailles: [{ taille: 'M', disponible: true }, { taille: 'L', disponible: true }],
  } as unknown as Produit

  it('choix toujours valable : repris tel quel', () => {
    expect(selectionValide(piece, { coloris: 'Blanc', taille: 'L', quantite: 2 })).toEqual({ coloris: 'Blanc', taille: 'L', quantite: 2 })
  })
  it('taille passée en rupture et coloris retiré : retour aux valeurs de départ, quantité gardée', () => {
    const apres = { ...piece, coloris: [{ nom: 'Noir', hex: '#000' }], tailles: [{ taille: 'M', disponible: true }, { taille: 'L', disponible: false }] } as Produit
    expect(selectionValide(apres, { coloris: 'Blanc', taille: 'L', quantite: 2 })).toEqual({ coloris: 'Noir', taille: null, quantite: 2 })
  })
  it('aucun choix précédent : premier coloris, aucune taille, quantité 1', () => {
    expect(selectionValide(piece)).toEqual({ coloris: 'Noir', taille: null, quantite: 1 })
  })
  it('une seule fiche retenue : le choix d\'une autre pièce n\'est pas repris', () => {
    noterSelection('essai', { coloris: 'Blanc', taille: 'M', quantite: 1 })
    expect(lireSelection('essai')?.taille).toBe('M')
    noterSelection('autre', { coloris: null, taille: null, quantite: 1 })
    expect(lireSelection('essai')).toBeUndefined()
  })
})
