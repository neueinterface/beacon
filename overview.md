# Semera

Semera is a local-first AI chat experience by Semera Labs.

It is designed to make local AI approachable, useful, and beautiful. Semera brings together model discovery, download, management, web-aware assistance, and conversation in a calm native experience that feels familiar from the first launch.

Semera is not for configuring inference engines. It is not a technical dashboard. It is a product for people who want to experience AI on their own devices with clarity, privacy, and control.

## Product Overview

Semera is the best place to experience local AI.

It combines the simplicity of a modern chat application with the trust and clarity of a curated model store. People can find models, understand what they are for, download them, and start a conversation without needing to understand the machinery behind them.

The product hides unnecessary complexity while preserving a sense of ownership. Models live on the user's device. Conversations feel personal. The interface remains quiet, direct, and understandable.

Semera makes local AI feel less like infrastructure and more like software.

Semera can also reach for the web when the user needs current information. This is intentionally a tool, not the default mode. The model remains local, the search key stays server-side, and web-backed answers expose their sources clearly.

## Vision

Local AI should be accessible to everyone.

Today, running models locally often requires technical knowledge, careful configuration, and comfort with unfamiliar concepts. Semera exists to remove that burden. It turns local AI from something people install and manage into something they simply use.

The long-term vision is to make Semera the most trusted and thoughtfully designed home for local models. A place where people can explore what local AI can do, choose models with confidence, and build lasting relationships with tools that respect their privacy and attention.

Semera is not trying to compete with frontier AI labs. It is not defined by the largest model or the newest benchmark. Its goal is to create the best product experience around local AI: calm, native, private, and human-centered.

## Core Principles

### Local First

Semera begins with the device.

Local models should feel immediate, private, and owned by the person using them. The product should make this ownership visible without making it technical. Users should understand that their models and conversations belong to them.

### Privacy and Ownership

Privacy is not a setting hidden in a menu. It is part of the product's foundation.

Semera should give users confidence that their conversations are personal and that their tools are under their control. The product should avoid patterns that make people feel watched, measured, or dependent on remote systems.

When web search is used, the boundary should be visible. The app should explain the source of web-backed context through source tags and should not imply that remote search is the same as local inference.

### Simplicity Over Complexity

Most users should never need to think about model configuration.

Semera should make good decisions on the user's behalf, explain choices clearly when needed, and avoid exposing complexity as a substitute for design. Advanced details may exist, but they should never define the primary experience.

### Curated, Not Overwhelming

Choice should create confidence, not anxiety.

Semera should favor curation over exhaustive lists. Models should be presented through clear purpose, quality, personality, and fit. The experience should help users answer simple questions: What is this good for? Why would I choose it? What can I do with it now?

### Beautiful by Default

Local AI deserves exceptional product design.

Every interaction in Beacon should feel considered: discovering a model, downloading it, starting a chat, switching contexts, managing storage, or returning to a conversation. Beauty is not decoration. It is how the product communicates care, trust, and ease.

### Human-Centered AI

Semera should make AI feel useful without making it feel dominant.

The product should support human intent, creativity, learning, and reflection. It should be clear about what models can do, gentle when they fall short, and designed around the person using them rather than the technology powering them.

### Native Platform Experiences

Semera should feel at home on every device it supports.

The interface should respect platform conventions, system behaviors, input methods, and user expectations. A native experience is not only about appearance. It is about responsiveness, integration, and trust.

### Calm Software

Semera should reduce noise.

The product should avoid urgency, clutter, and unnecessary interruption. It should feel composed and dependable. Local AI can be powerful without being loud.

## User Experience Philosophy

Semera should feel like the App Store for local models combined with a modern chat application.

The first experience should be simple: find a model, download it, start talking. The user should not be asked to make technical decisions before they have experienced value. Each step should feel guided, reversible, and safe.

Model discovery should be editorial and legible. A user should be able to browse by use case, tone, capability, or recommendation. The product should translate technical possibility into human language.

Chat should feel focused and personal. The interface should place attention on the conversation, not the system behind it. Controls should appear when useful and stay out of the way when not.

Management should feel calm and transparent. Users should understand what is on their device, how much space it uses, and how to remove or update it. These actions should feel like normal product interactions, not maintenance work.

Semera should make the powerful parts of local AI feel obvious and the difficult parts feel handled.

## Current Capabilities

Semera currently supports:

- Local MLX model loading and streaming through `BeaconModelRuntime`
- Apple Foundation Model support when available
- A curated model catalog with regular and reasoning models
- Thinking streams separated from final assistant answers
<!-- Web search routing and source dropdowns are not currently available.
- Automatic and explicit web search routing
- Source dropdowns with in-app Safari links
-->
- Chat history persistence
- Shortcuts/App Intents for asking the selected model

<!-- Web search is not currently available.
## Web-Aware Assistance

The app should decide carefully when to use web search.

Web search is appropriate for current events, prices, weather, sports scores, release dates, recent changes, source requests, and prompts where stale knowledge would likely hurt the answer. The user can force search with `/web` or opt out with `/noweb`.

When the web is used, the answer should cite sources by number and show a source dropdown above the response. The source control should remain visually calm: anchored at the top of the answer, secondary in color, and revealed with a soft downward transition.
-->

## Long-Term Direction

Semera can become the trusted home for personal AI on the user's own devices.

Over time, it should grow from a beautiful local chat experience into a broader environment for discovering, using, and understanding local models. This includes richer model curation, more personal workflows, deeper platform integration, and better ways to match people with the right model for the task.

The product should remain disciplined as it grows. New capabilities should not compromise clarity. Power should be introduced through thoughtful defaults, progressive disclosure, and strong taste.

Semera's opportunity is not to make local AI more complex. It is to make local AI feel inevitable: private, capable, understandable, and beautifully designed.
