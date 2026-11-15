import { describe, expect, it } from 'vitest'
import { TITRE_SITE, titrePage } from '@/lib/titres'
import { categories, produits } from '@/lib/catalogue'

describe('titre de l\'onglet par page', () => {
  it('accueil : titre du site', () => {
    expect(titrePage('/')).toBe(TITRE_SITE)
  })
  it('fiche : marque — nom, comme la page partagée ; slash final toléré', () => {
    const p = produits[0]
    expect(titrePage(`/produit/${p.slug}`)).toBe(`${p.marque} — ${p.nom} · H MODE`)
    expect(titrePage(`/produit/${p.slug}/`)).toBe(`${p.marque} — ${p.nom} · H MODE`)
  })
  it('boutique : rayon, genre, soldes', () => {
    const c = categories.find(x => x.actif)!
    expect(titrePage(`/boutique/${c.slug}`)).toBe(`${c.nom} · H MODE`)
    expect(titrePage('/boutique', '?genre=femme')).toBe('Femmes · H MODE')
    expect(titrePage('/boutique', '?solde=1')).toBe('Soldes · H MODE')
    expect(titrePage('/boutique')).toBe('Boutique · H MODE')
  })
  it('pages fixes, compte et adresse inconnue', () => {
    expect(titrePage('/cgv')).toBe('Conditions générales de vente · H MODE')
    expect(titrePage('/compte/favoris')).toBe('Mon compte · H MODE')
    expect(titrePage('/produit/inexistant')).toBe('Page introuvable · H MODE')
    expect(titrePage('/nulle-part')).toBe('Page introuvable · H MODE')
  })
})
