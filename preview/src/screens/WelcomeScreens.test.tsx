import { cleanup, render, screen, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { OnboardingScreen, SplashScreen } from './WelcomeScreens'

afterEach(cleanup)

function renderOnboarding(language: 'tr' | 'en' = 'tr') {
  const onFinish = vi.fn()
  return { ...render(<OnboardingScreen language={language} onFinish={onFinish} />), onFinish }
}

function expectCurrentPage(name: string) {
  expect(screen.getByRole('button', { name })).toHaveAttribute('aria-current', 'step')
  expect(document.querySelectorAll('[aria-current="step"]')).toHaveLength(1)
}

describe('Welcome screen presentation and navigation', () => {
  it('uses the semantic Turkish launch without decorative or fictitious progress', () => {
    const {container}=render(<SplashScreen />)
    expect(screen.getByLabelText('Ringify açılış ekranı')).toBeInTheDocument()
    expect(screen.getAllByText('Ringify').length).toBeGreaterThan(0)
    expect(screen.getByText('Zil Sesi Stüdyosu')).toBeInTheDocument()
    expect(container.querySelector('.v3-splash')).toBeInTheDocument()
    expect(container.querySelector('.splash-glow,.splash-loader')).toBeNull()
    expect(screen.queryByRole('progressbar')).not.toBeInTheDocument()
    expect(screen.queryByRole('button')).not.toBeInTheDocument()
    expect(screen.queryByText(/\d+\s*%/)).not.toBeInTheDocument()
  })

  it('localizes the product launch label and subtitle into English', () => {
    render(<SplashScreen language="en" />)
    expect(screen.getByLabelText('Ringify launch screen')).toBeInTheDocument()
    expect(screen.getByText('Ringtone Studio')).toBeInTheDocument()
    expect(screen.queryByText('Zil Sesi Stüdyosu')).not.toBeInTheDocument()
  })

  it('does not steal initial focus and exposes only the five real first-page actions', () => {
    const host = render(<button type="button">Odak sahibi</button>)
    const originalFocus = host.getByRole('button', { name: 'Odak sahibi' })
    originalFocus.focus()
    const { container, onFinish } = renderOnboarding()
    expect(originalFocus).toHaveFocus()
    expect(screen.getByRole('heading', { name: 'Sesini içeri aktar' })).toHaveAttribute('tabindex', '-1')
    expect(within(container).getAllByRole('button')).toHaveLength(5)
    expect(screen.queryByRole('button', { name: 'Geri' })).not.toBeInTheDocument()
    expectCurrentPage('1. sayfa')
    expect(container.querySelector('.v6-welcome')).toBeInTheDocument()
    expect(container.querySelector('.v6-onboarding.onboarding-screen')).toBeInTheDocument()
    expect(container.querySelector('.art-wave')).toBeNull()
    expect(container.querySelector('input[type="file"], audio')).toBeNull()
    expect(screen.queryByRole('slider')).not.toBeInTheDocument()
    expect(onFinish).not.toHaveBeenCalled()
  })

  it('advances through all three preserved headings and completes only with the final action', async () => {
    const user = userEvent.setup()
    const { onFinish } = renderOnboarding()
    await user.click(screen.getByRole('button', { name: 'İleri' }))
    expect(screen.getByRole('heading', { name: 'Tam istediğin anı seç' })).toHaveFocus()
    expectCurrentPage('2. sayfa')
    expect(onFinish).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'İleri' }))
    expect(screen.getByRole('heading', { name: 'Zil sesine dönüştür' })).toHaveFocus()
    expectCurrentPage('3. sayfa')
    expect(screen.getAllByRole('button')).toHaveLength(6)
    expect(onFinish).not.toHaveBeenCalled()
    await user.click(screen.getByRole('button', { name: 'Başla' }))
    expect(onFinish).toHaveBeenCalledOnce()
  })

  it('supports dot/back navigation with one current step and heading focus on every real transition', async () => {
    const user = userEvent.setup()
    const { onFinish } = renderOnboarding()
    await user.click(screen.getByRole('button', { name: '3. sayfa' }))
    expect(screen.getByRole('heading', { name: 'Zil sesine dönüştür' })).toHaveFocus()
    expectCurrentPage('3. sayfa')
    await user.click(screen.getByRole('button', { name: 'Geri' }))
    expect(screen.getByRole('heading', { name: 'Tam istediğin anı seç' })).toHaveFocus()
    expectCurrentPage('2. sayfa')
    await user.click(screen.getByRole('button', { name: 'Geri' }))
    expect(screen.getByRole('heading', { name: 'Sesini içeri aktar' })).toHaveFocus()
    expectCurrentPage('1. sayfa')
    expect(screen.queryByRole('button', { name: 'Geri' })).not.toBeInTheDocument()
    expect(onFinish).not.toHaveBeenCalled()
  })

  it.each([1, 2, 3])('keeps Skip functional on Turkish page %s', async page => {
    const user = userEvent.setup()
    const { onFinish } = renderOnboarding()
    if (page !== 1) await user.click(screen.getByRole('button', { name: `${page}. sayfa` }))
    await user.click(screen.getByRole('button', { name: 'Geç' }))
    expect(onFinish).toHaveBeenCalledOnce()
  })

  it('localizes all English pages, back/skip/dots and the final primary action', async () => {
    const user = userEvent.setup()
    const { onFinish } = renderOnboarding('en')
    expect(screen.getByRole('heading', { name: 'Import your sound' })).toBeInTheDocument()
    expectCurrentPage('Page 1')
    expect(screen.getByRole('button', { name: 'Skip' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Next' }))
    expect(screen.getByRole('heading', { name: 'Choose the perfect moment' })).toHaveFocus()
    expectCurrentPage('Page 2')
    expect(screen.getByRole('button', { name: 'Back' })).toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Page 3' }))
    expect(screen.getByRole('heading', { name: 'Turn it into a ringtone' })).toHaveFocus()
    expectCurrentPage('Page 3')
    expect(screen.queryByRole('button', { name: 'İleri' })).not.toBeInTheDocument()
    await user.click(screen.getByRole('button', { name: 'Get Started' }))
    expect(onFinish).toHaveBeenCalledOnce()
  })

  it('supports keyboard Enter/Space activation and moves focus to the new page heading', async () => {
    const user = userEvent.setup()
    const { onFinish } = renderOnboarding()
    screen.getByRole('button', { name: 'İleri' }).focus()
    await user.keyboard('{Enter}')
    expect(screen.getByRole('heading', { name: 'Tam istediğin anı seç' })).toHaveFocus()
    screen.getByRole('button', { name: '3. sayfa' }).focus()
    await user.keyboard(' ')
    expect(screen.getByRole('heading', { name: 'Zil sesine dönüştür' })).toHaveFocus()
    screen.getByRole('button', { name: 'Başla' }).focus()
    await user.keyboard('{Enter}')
    expect(onFinish).toHaveBeenCalledOnce()
  })
})
