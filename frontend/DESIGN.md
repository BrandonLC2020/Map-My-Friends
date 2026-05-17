---
name: Map My Friends
description: Technical Luxury for Global Connections.
colors:
  primary: "#3F51B5" # Indigo
  secondary: "#FF4081" # Pink Accent
  thermal-core: "#FF3B30" # Thermal Heat Core
  thermal-corona: "#FF9500" # Thermal Heat Corona
  glass-base: "#FFFFFF1A" # Glass Surface (10% Opacity)
  neutral-bg: "#F5F5F5" # Light Gray
  airport: "#1565C0"
  major-station: "#E65100"
typography:
  display:
    fontFamily: "Montserrat, sans-serif"
    fontSize: "57px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "-0.25px"
  body:
    fontFamily: "Open Sans, sans-serif"
    fontSize: "16px"
    fontWeight: 300
    lineHeight: 1.5
    letterSpacing: "0.5px"
rounded:
  sm: "8px"
  md: "16px"
  lg: "30px"
spacing:
  xs: "8px"
  sm: "16px"
  md: "24px"
  lg: "32px"
components:
  nav-glass:
    backgroundColor: "{colors.glass-base}"
    rounded: "{rounded.lg}"
    padding: "10px 20px"
  button-thermal:
    backgroundColor: "{colors.thermal-core}"
    textColor: "#FFFFFF"
    rounded: "{rounded.sm}"
---

# Design System: Map My Friends

## 1. Overview

**Creative North Star: "The Technical Luxury Instrumentation"**

Map My Friends is designed as a high-fidelity spatial instrument. It rejects generic flatness in favor of an aesthetic governed by physical materiality, optical depth, and energetic response. The interface feels less like software and more like a precision hardware tool—a "Digital Swiss Watch" for the world's most connected networks.

**Key Characteristics:**
- **Refractive Depth**: Hierarchy is conveyed through layered translucency and optical distortion (Glass).
- **Physical Inertia**: Movement carries mass and momentum; interactions are dialogues of physics.
- **Thermal Energy**: The machine responds to touch with a localized radiant glow (Thermal Heat).

## 2. Colors

The palette is anchored by the concept of "Technical Luxury"—refined neutrals accented by intense energy gradients.

### Primary
- **Indigo Brand** (#3F51B5): Used sparingly for structural branding and primary focus points.

### Secondary
- **Pink Accent** (#FF4081): Used for high-contrast highlights and energetic UI feedback.

### Thermal (LLC Standard)
- **Thermal Heat** (#FF3B30 to #FF9500): A gradient representing the excitation of the interface under user touch.

### Neutral
- **Glass Surface** (#FFFFFF1A): The foundational material. Pristine, refractive, and structural.

### Named Rules
**The Rare Accent Rule.** High-chroma accents (Indigo, Pink, Thermal) must occupy ≤10% of any screen surface. Their rarity ensures their authoritative power.

## 3. Typography

Industrial strength meets effortless technical legibility.

- **Display (Montserrat, 700, 57px)**: Used for structural clarity and industrial headlines.
- **Body (Open Sans, 300, 16px)**: Optimized for effortless reading in dense technical and spatial data.

## 4. Elevation

Map My Friends rejects traditional drop shadows. Depth is achieved through the **Refractive Depth** model.

**The Refraction-Over-Shadow Rule.** Depth is conveyed by the blurring of content *behind* a surface, not by the casting of a shadow *below* it. All floating panels use 20px Backdrop Blur (Sigma 20.0).

## 5. Components

### Navigation (Glass)
- **Shape**: Highly rounded (30px radius).
- **Material**: 10% opaque Glass with 20px blur.
- **States**: Selection is indicated by a 20% opaque background lift, not a solid color fill.

### RefractiveGlass (LLC Standard)
- **Blur**: Sigma 20.0.
- **Border**: 0.5px semi-transparent (20% white) to define the precision edge.

### Interactive Elements
- **Response**: Upon contact, elements emit a **Thermal Glow**.
- **Excitation**: 50ms expansion.
- **Dissipation**: 300ms cooling cycle.

## 6. Do's and Don'ts

### Do:
- **Do** use Refractive Glass for all floating UI layers.
- **Do** utilize Montserrat for all display-level hierarchy.
- **Do** implement Interaction Physics (Stiffness: 180, Damping: 12) for all state returns.

### Don't:
- **Don't** use standard drop shadows (box-shadow).
- **Don't** use "Side-stripe" borders on cards or list items.
- **Don't** use cartoonish or bubbly icons; stick to precise, geometric line art.
- **Don't** allow dark mode to feel like "dark blue software"; it must feel like "pristine glass in a void".
