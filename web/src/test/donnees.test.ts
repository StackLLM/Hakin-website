import { describe, expect, it } from 'vitest'
import { renderHook } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { createElement, type ReactNode } from 'react'
import { appliquerDonnees, useDonnees } from '@/lib/donnees'
import { produits } from '@/lib/catalogue'
import { useLiensPrincipaux } from '@/components/EnTete'

const enveloppe = ({ children }: { children: ReactNode }) => createElement(MemoryRouter, null, children)

describe('catalogue appliqué depuis la base', () => {
  it('même contenu que la copie : la version ne bouge pas (la page ne se remonte pas, la saisie reste)', () => {
    const c = { produits: structuredClone(produits), boutique: null, textes: null }
    appliquerDonnees(c, 'copie')
    const v = useDonnees.getState().version
    appliquerDonnees(structuredClone(c), 'base')
    expect(useDonnees.getState().version).toBe(v)
    expect(useDonnees.getState().source).toBe('base')
  })
  it('contenu différent : nouvelle version', () => {
    const v = useDonnees.getState().version
    const modifies = structuredClone(produits)
    modifies[0] = { ...modifies[0], nom: `${modifies[0].nom} (modifié)` }
    appliquerDonnees({ produits: modifies, boutique: null, textes: null }, 'base')
    expect(useDonnees.getState().version).toBe(v + 1)
  })
})

describe('menu principal', () => {
  it('« Soldes » masqué sans pièce en solde, affiché dès qu\'une pièce a un prix barré', () => {
    const sansSolde = structuredClone(produits).map(p => ({ ...p, prixDH: 100, prixBarreDH: null }))
    appliquerDonnees({ produits: sansSolde, boutique: null, textes: null }, 'base')
    const { result, rerender } = renderHook(() => useLiensPrincipaux(), { wrapper: enveloppe })
    expect(result.current.map(l => l.libelle)).not.toContain('Soldes')

    const avecSolde = sansSolde.map((p, i) => (i === 0 ? { ...p, prixBarreDH: 150 } : p))
    appliquerDonnees({ produits: avecSolde, boutique: null, textes: null }, 'base')
    rerender()
    expect(result.current.map(l => l.libelle)).toContain('Soldes')
  })
})
