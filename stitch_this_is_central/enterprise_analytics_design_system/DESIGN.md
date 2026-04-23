---
name: Enterprise Analytics Design System
colors:
  surface: '#f8f9ff'
  surface-dim: '#cbdbf5'
  surface-bright: '#f8f9ff'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#eff4ff'
  surface-container: '#e5eeff'
  surface-container-high: '#dce9ff'
  surface-container-highest: '#d3e4fe'
  on-surface: '#0b1c30'
  on-surface-variant: '#434655'
  inverse-surface: '#213145'
  inverse-on-surface: '#eaf1ff'
  outline: '#737686'
  outline-variant: '#c3c6d7'
  surface-tint: '#0053db'
  primary: '#004ac6'
  on-primary: '#ffffff'
  primary-container: '#2563eb'
  on-primary-container: '#eeefff'
  inverse-primary: '#b4c5ff'
  secondary: '#006c49'
  on-secondary: '#ffffff'
  secondary-container: '#6cf8bb'
  on-secondary-container: '#00714d'
  tertiary: '#784b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#996100'
  on-tertiary-container: '#ffeedd'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#dbe1ff'
  primary-fixed-dim: '#b4c5ff'
  on-primary-fixed: '#00174b'
  on-primary-fixed-variant: '#003ea8'
  secondary-fixed: '#6ffbbe'
  secondary-fixed-dim: '#4edea3'
  on-secondary-fixed: '#002113'
  on-secondary-fixed-variant: '#005236'
  tertiary-fixed: '#ffddb8'
  tertiary-fixed-dim: '#ffb95f'
  on-tertiary-fixed: '#2a1700'
  on-tertiary-fixed-variant: '#653e00'
  background: '#f8f9ff'
  on-background: '#0b1c30'
  surface-variant: '#d3e4fe'
typography:
  display-lg:
    fontFamily: Manrope
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Manrope
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-sm:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  label-bold:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  stat-number:
    fontFamily: Manrope
    fontSize: 28px
    fontWeight: '700'
    lineHeight: 34px
  caption:
    fontFamily: Inter
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  base: 4px
  container-padding: 24px
  gutter-grid: 20px
  card-internal: 20px
  stack-sm: 8px
  stack-md: 16px
---

## Brand & Style
The design system is engineered for high-density enterprise environments where clarity, speed of data processing, and professional reliability are paramount. It targets decision-makers and project managers who require a centralized source of truth.

The aesthetic follows a **Modern Corporate** movement. It prioritizes functional minimalism with high-quality white space, light-gray structural borders, and purposeful pops of color to denote status and priority. The interface evokes a sense of calm efficiency, utilizing a light mode default to maintain high contrast and readability. Visual hierarchy is achieved through subtle layering rather than aggressive shadows, creating a "clean-room" feel that feels premium and trustworthy.

## Colors
This design system utilizes a refined palette optimized for dashboard utility. 

- **Primary:** A vibrant Blue (#2563EB) is used for primary actions, active navigation states, and key data points.
- **Surface & Background:** The layout uses a soft gray-white (#F8FAFC) for the canvas, with pure white (#FFFFFF) reserved for elevated cards and data containers.
- **Semantic Palette:** A standard traffic-light system is implemented for status badges and chart data:
    - **Green (#10B981):** "Running," "Completed," or positive growth.
    - **Orange/Yellow (#F59E0B):** "Pending," "Delayed," or neutral trends.
    - **Red (#EF4444):** Negative trends or "At Risk" statuses.
- **Neutral Scales:** Text is primarily rendered in Slate/Zinc tones to avoid the harshness of pure black, ensuring better eye comfort over long periods of use.

## Typography
The system employs a dual-font strategy. **Manrope** is used for headlines, card titles, and large numerical displays to provide a modern, geometric character. **Inter** is the workhorse for tabular data, body text, and labels, selected for its exceptional legibility at small sizes.

Numerical data in charts and tables should use tabular figures where possible to ensure columns align vertically. Hierarchy is reinforced through weight (600/700 for titles) and color (Slate-900 for titles vs Slate-500 for captions).

## Layout & Spacing
The layout follows a **Fluid Grid** model with a 12-column foundation. 

- **Containers:** All dashboard content is housed within white cards that typically span 3, 4, 6, or 12 columns depending on the data density.
- **Rhythm:** A 4px base unit controls all spacing. Standard card margins are 24px, while internal card padding is set to 20px to maximize information density without feeling cramped.
- **Density:** Table rows use a vertical padding of 12px to maintain a professional "Enterprise" density that allows for 10-15 rows to be visible without excessive scrolling.

## Elevation & Depth
Depth is conveyed primarily through **Tonal Layers** and **Low-contrast outlines**. 

- **Surfaces:** The canvas background is tinted, while cards are pure white.
- **Borders:** Instead of heavy shadows, the system uses 1px solid borders (#E2E8F0) to define card boundaries.
- **Shadows:** A single, extremely subtle ambient shadow (0px 1px 3px rgba(0,0,0,0.05)) is applied to the main cards to lift them slightly from the canvas. 
- **Interactivity:** On hover, interactive elements like project list rows or action buttons may increase slightly in shadow depth or change background color to a very light blue tint.

## Shapes
The shape language is **Soft** and restrained.

- **Cards & Inputs:** Standard components use a 0.5rem (8px) corner radius to strike a balance between modern friendliness and professional structure.
- **Buttons:** Primary buttons also use an 8px radius.
- **Badges:** Status chips and progress bar containers use a more pill-shaped approach (full rounding) to differentiate them from structural layout elements.
- **Icons:** Use icons within circles or squi-circles for metric tiles to create a distinct visual anchor.

## Components

- **Metric Cards:** Feature a circular icon container on the left, a large statistical number in the center, and a small percentage indicator (trend) at the bottom.
- **Buttons:** 
    - *Primary:* Solid Blue (#2563EB) with white text and a leading icon.
    - *Ghost/Secondary:* No background, slate-colored text, used for "View All" or secondary actions.
- **Status Badges:** Use a light-tinted background of the semantic color with high-contrast text (e.g., Light Green BG with Dark Green text).
- **Data Tables:** Feature light gray headers with bolded labels. Rows should have a subtle bottom border and include horizontal progress bars for "Progress" columns.
- **Progress Bars:** Use a 6px height with a gray track and a solid primary/semantic color fill.
- **Input Fields:** Search bars should be subtle, with a light gray border and a leading magnifying glass icon.
- **Charts:** Donut charts and line graphs must use the defined semantic palette. Line charts should include a soft gradient fill (area chart style) beneath the primary stroke.