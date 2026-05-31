# SANCTUM: Digital Wellness RPG

SANCTUM is a gamified digital wellness mobile application designed to help users identify, combat, and reframe negative thought patterns (cognitive distortions) through an immersive, cyberpunk-inspired RPG interface. 

The core mechanics utilize Cognitive Behavioral Therapy (CBT) frameworks, transforming internal cognitive challenges into real-time tactical encounters.

DEMO Link: https://drive.google.com/file/d/1b83vzuGvG0lfGEo3ffmzRX73MoSKnvyo/view?usp=sharing

Code explanation Link: https://drive.google.com/file/d/1mo6YDTmupiRA1bdahu3njGsBSUg8R5t6/view?usp=sharing
---

## 🛠️ System Architecture Overview

The platform is engineered using a decoupled **Modern 3-Tier Architecture** implementing a **Backend-for-Frontend (BFF)** pattern to isolate client execution from heavy cognitive computation and data state mutations.

<img width="1102" height="1189" alt="sysarch" src="https://github.com/user-attachments/assets/8d0e2ff3-47e4-46bc-9848-81b5d910d876" />

Architectural Breakdown
Presentation (Client) Tier: Built with Flutter (Dart). It handles local state management, rendering high-framerate gameplay aesthetics, and direct user interaction. High-performance, non-sensitive data pathways (e.g., loading historical archives or checking item catalogs) read directly from the Data Tier to slash latency.

Application (BFF) Layer: Powered by a Node.js Express API deployed on Vercel Serverless Functions. This layer securely encapsulates sensitive API credentials, anchors our system security logic, and maps data mutations strictly on the server side.

Data Tier: Backed by Supabase (PostgreSQL). It manages user state, session authentication, and guards data persistence using strict relational mapping and database-level Row Level Security (RLS).

Cognitive Tier: Driven by Google Gemini 2.5 Flash. Operating purely as a structured JSON computation model rather than a conversational chatbot, it dynamically grades cognitive reframes using complex CBT rubrics.

🛡️ Core Security Engineering
The Prompt Firewall
To prevent malicious payload delivery and protect game progression mechanics from spoofing, all client text inputs are aggressively handled by a backend Prompt Firewall before reaching the LLM:

Isolation Constraints: The raw client string is strictly bound inside explicit structural delimiters ([[[ user_input ]]]) programmatically inside the Node.js layer. This guarantees the AI evaluates the text purely as data context, neutralizing prompt injection vectors.

Forced JSON Schemas: By configuring the Gemini SDK with a strict responseMimeType: "application/json", the backend forces a deterministic response format (returning explicit integer damage metrics and localized logs). This completely removes structural unpredictability from the AI pipeline.

📁 Repository Structure (Monorepo)
Plaintext
sanctum-project/
├── client/              # Flutter Presentation Application
│   ├── lib/             # Dart UI, HUD controllers, and local views
│   ├── pubspec.yaml     # Flutter dependencies & assets configurations
│   └── .gitignore       # Client compilation ignore rules
└── server/              # Node.js Serverless Backend API
    ├── index.js         # Express main entry point and firewall orchestration
    ├── vercel.json      # Serverless route targeting and build controls
    ├── package.json     # Node script wrappers and dependencies
    └── .gitignore       # Environment secret variable protection rules
🚀 Deployment & Local Environment Setup
1. Prerequisites
Flutter SDK (3.x or higher)

Node.js (v18.x or higher)

Vercel CLI (npm install -g vercel)

2. Backend Configuration (/server)
Navigate to the server directory and install dependencies:

Bash
cd server
npm install
Create a local .env configuration file inside /server containing your credentials:

Code snippet
GEMINI_API_KEY=your_gemini_api_key_here
SUPABASE_URL=your_supabase_project_url_here
SUPABASE_ANON_KEY=your_supabase_client_key_here
To deploy serverless functions live to production:

Bash
vercel
Note: Make sure to map your .env variables inside your Vercel Dashboard under Project Settings -> Environment Variables before running a production build.

3. Frontend Configuration (/client)
Navigate to the client directory and restore local packages:

Bash
cd ../client
flutter pub get
Configure your environment routing endpoints. Update your endpoint variables to route your HTTP requests to your live, aliased production link:

Dart
class ApiConfig {
  // Local testing target: '[http://10.0.2.2:3000](http://10.0.2.2:3000)'
  static const String baseUrl = '[https://sanctum-api.vercel.app](https://sanctum-api.vercel.app)'; 
}
Run your target mobile build environment:

Bash
flutter run
📝 Technologies Used
Frontend: Flutter, Dart, HTTP Client

Backend: Node.js, Express, Google Gen AI SDK

Database & Hosting: Supabase, PostgreSQL, Vercel Serverless Platform

AI Model Engine: Google Gemini 2.5 Flash
