# Design System Strategy: The Neon-Glass Protocol

## 1. Overview & Creative North Star
**Creative North Star: "The Kinetic Sanctuary"**

This design system moves away from the utilitarian "grid of boxes" common in ride-sharing and moves toward an immersive, cinematic experience. It treats the interface not as a static screen, but as a high-tech dashboard viewed through a futuristic lens. 

To achieve a "next-gen" feel, we employ **intentional asymmetry** and **tonal depth**. By layering semi-transparent "glass" surfaces over a deep, infinite background, we create a sense of speed and fluidity. We break the template look by allowing elements to overlap slightly and by using aggressive typographic scales that feel more like a premium editorial magazine than a standard utility app.

## 2. Colors & Surface Architecture
The palette is rooted in a "Deep Dark" philosophy, utilizing a pitch-black foundation to let our electric accents truly "glow."

### The "No-Line" Rule
**Explicit Instruction:** Do not use 1px solid borders to define sections. Traditional dividers create visual clutter and "trap" the user's eye. Boundaries must be defined solely through:
- **Background Color Shifts:** Using `surface-container-low` against a `background` floor.
- **Tonal Transitions:** Leveraging subtle gradients from `primary` to `primary-container`.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers—like stacked sheets of frosted glass.
- **Floor (`surface` / `background`):** The infinite base. Use `#0e0e13`.
- **Primary Containers (`surface-container`):** For main content areas.
- **Elevated Elements (`surface-container-high`):** For interactive cards.
- **Glass Overlays:** For floating menus and navigation bars.

### The "Glass & Gradient" Rule
To achieve the "Next-Gen" modernization, use **Glassmorphism** for all floating elements (modals, bottom sheets, navigation). 
- **Effect:** Apply a semi-transparent `surface-variant` color with a `20px` to `40px` backdrop blur.
- **Signature Textures:** Main CTAs should never be flat. Use a linear gradient (45°) transitioning from `primary` (#81ecff) to `primary-container` (#00e3fd). This provides a "liquid light" soul to the interface.

## 3. Typography
Our typography pairing balances technical precision with high-fashion impact.

- **Display & Headlines (`Space Grotesk`):** This is our "high-tech" voice. The geometric quirks of Space Grotesk at `display-lg` (3.5rem) or `headline-md` (1.75rem) provide an authoritative, editorial feel that suggests cutting-edge engineering.
- **Body & Labels (`Inter`):** Inter is used for maximum readability during high-speed interactions. Its neutral tone ensures that complex data (pricing, ETAs, driver names) remains legible even when layered over glass surfaces.
- **Hierarchy Tip:** Use `label-sm` in all-caps with increased letter spacing for category headers to create a "technical blueprint" aesthetic.

## 4. Elevation & Depth
In this system, depth is a function of light and transparency, not "drop shadows."

### The Layering Principle
Achieve lift by stacking tiers. Place a `surface-container-lowest` card on a `surface-container-low` section. This creates a "recessed" or "elevated" look through value contrast alone.

### Ambient Shadows
Shadows are used sparingly and only for "True Floating" elements (e.g., a car icon on a map). 
- **Spec:** Large blur (24pt+), low opacity (6%).
- **Color:** Tint the shadow with `secondary` (#ac89ff) instead of pure black to mimic the ambient glow of the screen's "neon" accents.

### The "Ghost Border" Fallback
If a container bleeds into the background, use a **Ghost Border**:
- **Value:** `outline-variant` (#48474d) at **15% opacity**. It should be felt, not seen.

## 5. Components

### Buttons (The Kinetic Triggers)
- **Primary:** Gradient fill (`primary` to `primary-container`), `xl` (1.5rem) corner radius. Use a subtle outer glow using the `primary_dim` color for the active state.
- **Secondary:** Glassmorphic fill (low-opacity `on_surface`) with a "Ghost Border."
- **Tertiary:** No background. Bold `primary` typography for high-contrast "ghost" actions.

### Cards & Lists (The Editorial Feed)
- **Rule:** **No dividers.** Separate trip history or vehicle options using `md` (0.75rem) spacing or subtle shifts from `surface-container-low` to `surface-container-high`.
- **Layout:** Use `xl` (1.5rem) rounded corners to maintain the friendly-yet-futuristic vibe.

### Input Fields (The Command Line)
- **Style:** Understated. Use `surface-container-highest` as a solid base with a `primary` glow only on focus. Helper text should use `label-md` in `on_surface_variant`.

### Floating Action Navigation (The Command Center)
- Instead of a standard bottom nav bar, use a detached, floating glass container with `full` (9999px) roundedness. This enhances the "fluid" and "fast" feel of the Flutter app.

## 6. Do’s and Don’ts

### Do:
- **Do** use `primary` and `secondary` accents as "light sources." If a card is important, give it a subtle 1px "top-light" gradient stroke to mimic light hitting the edge of glass.
- **Do** embrace white space. "Spacious layouts" are the hallmark of premium design. 
- **Do** use `Space Grotesk` for numbers. Price points and ETAs should feel like high-end telemetry.

### Don't:
- **Don't** use pure white (#FFFFFF) for text. Use `on_surface` (#f9f5fd) to prevent "retina burn" in dark mode.
- **Don't** use standard Material dividers. If you feel the need for a line, use a spacing gap instead.
- **Don't** use 100% opaque cards. The "Next-Gen" feel relies on the background (maps or gradients) being slightly visible through the UI layers.