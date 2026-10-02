---
name: professional-mobile-ui
description: Professional organization-level mobile UI and UX guidelines for Flutter. Use when styling, redesigning, or polishing mobile applications to enterprise, executive, and high-end consumer standards (Linear, Apple, Vercel design aesthetics).
---

# Professional Organization-Level Mobile UI & Design System

## Core Design Principles

1. **Executive Visual Hierarchy & Typography**:
   - **Display Headings**: Use `GoogleFonts.syne` or `GoogleFonts.outfit` with tight tracking (`letterSpacing: -0.5`), bold weights (600–700), and crisp white (`#FFFFFF` or `#F8FAFC`).
   - **Body & Metadata**: Use `GoogleFonts.inter` for maximum legibility at small sizes (11–14px), with clean neutral contrast (`#94A3B8` / `#64748B`).
   - **Codes & Technical Stamps**: Use `GoogleFonts.jetBrainsMono` for registration numbers, timestamps, hashes, and slots.
   - **Font Locking**: Always enforce font families explicitly across `ThemeData`, `AppBarTheme`, and text styles so device-level cursive or default fonts never leak into the UI.

2. **Color Palette & Glassmorphic Elevation**:
   - **Base Canvas**: Deep pitch-black OLED background (`#08080C` or `#0B0F17`).
   - **Card Surfaces**: Translucent dark surfaces (`#121620` or `rgba(255, 255, 255, 0.04)`) with subtle 1px border strokes (`#1E293B` or `rgba(255, 255, 255, 0.08)`).
   - **Brand & Accent Spectrum**:
     - Electric Violet / Brand: `#8B5CF6` / `#9D4EDD`
     - Tech Blue: `#3B82F6` / `#4F8BFF`
     - Emerald Verified: `#10B981`
     - Amber Warning: `#F59E0B`
     - Crimson Danger: `#EF4444`

3. **Layout Discipline & Zero-Overflow**:
   - **Wrap vs Row**: Never pack variable-length metadata (badges, names, dates, buttons) in an unbounded `Row`. Always use `Wrap` with `spacing: 6, runSpacing: 4`, or `Expanded`/`Flexible` with `TextOverflow.ellipsis`.
   - **Touch Targets**: Minimum 44x44px interactive tap zones with subtle haptic feedback and rounded ink ripples.
   - **Pill Badges**: Use capsule shape (`BorderRadius.circular(20)`), 4px vertical / 10px horizontal padding, with subtle border and 12-18% alpha background.

4. **Micro-Interactions & Polish**:
   - Smooth sheet entries with pill drag handles.
   - Skeleton shimmer loaders rather than raw blank spinners.
   - Modern floating or docked bottom navigation bars with custom active glows.
   - Floating action buttons with high contrast and tactile elevation.
