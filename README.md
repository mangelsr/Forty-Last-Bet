# Fourty Last Bet

🎮 **[Play on Itch.io](https://mangelsr.itch.io/fourty-last-bet)**

**Fourty Last Bet** is a digital implementation of the traditional Ecuadorian card game **"Cuarenta"**, built in Godot 4. This project serves as a technical demonstration of game architecture, UI systems, and rule implementation for a job application showcase.

## 🎮 Game Overview

In **Fourty Last Bet**, you face off against an AI opponent in a high-stakes match of Cuarenta. Your goal is to reach 40 points before your opponent by capturing cards, forcing "Caidas" (matching the last card played), and clearing the table for a "Limpia".

### Key Rules (Cuarenta)
- **Capture**: Match a card on the table with one from your hand to capture it.
- **Sum & Sequence**: Capture cards that sum up to your card's value, and automatically pick up subsequent cards in sequence (J, Q, K).
- **Caida**: Match the card your opponent *just* played for an instant **+2 points**.
- **Limpia**: Clear the entire table for a **+2 points** bonus.
- **Ronda**: Get **+2 points** if your initial hand has 3 cards of the same value.
- **Cartón**: At the end of the deck, whoever has captured more than 19 cards gets extra points.

## ✨ Features

- **Full Game Loop**: Play through the entire 40-card deck with automatic dealing, round management, and reshuffling until a winner hits 40 points.
- **Smart Scoring**: Real-time scoring for all Cuarenta events, including complex captures and hand bonuses.
- **Dynamic VFX**: pop-up visual effects for major events like *CAIDA!*, *LIMPIA!*, and *VICTORY!*.
- **Procedural Card UI**: Cards are generated procedurally using Godot's Control nodes, allowing for flexible theming and effects without static assets.

## 🛠️ Technology Stack

- **Engine**: Godot 4.x
- **Language**: GDScript
- **Assets**: Custom procedural UI, SVG icons.

## 🚀 How to Play

1. **Clone the repository**.
2. Open the project in **Godot 4.3** (or later).
3. Run the **Main Scene** (`src/scenes/game_board/GameBoard.tscn`).
4. Drag and drop cards from your hand to the table to play.
5. Beat the AI to 40 points!


---
*Created by Miguel Sanchez*
