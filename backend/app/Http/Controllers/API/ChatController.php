<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\Chat;
use App\Models\AiConfig;
use App\Models\GlobalAiGuideline;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class ChatController extends Controller
{
    public function index(Request $request)
    {
        $request->validate([
            'receiver_type' => 'required|in:self,ai'
        ]);

        $messages = Chat::where('user_id', $request->user()->id)
            ->where('receiver_type', $request->receiver_type)
            ->orderBy('created_at', 'asc')
            ->get();

        return response()->json($messages);
    }

    public function store(Request $request)
    {
        $request->validate([
            'receiver_type' => 'required|in:self,ai',
            'message' => 'required',
            'is_ai' => 'boolean'
        ]);

        $chat = Chat::create([
            'user_id' => $request->user()->id,
            'receiver_type' => $request->receiver_type,
            'message' => $request->message,
            'is_ai' => $request->is_ai ?? false
        ]);

        return response()->json($chat);
    }

    public function clear(Request $request)
    {
        $request->validate([
            'receiver_type' => 'required|in:self,ai'
        ]);

        Chat::where('user_id', $request->user()->id)
            ->where('receiver_type', $request->receiver_type)
            ->delete();

        return response()->json(['message' => 'Chat history cleared']);
    }

    // ── AI Chat Reply Generator ──────────────────────────────────────────
    public function generateAiReply(Request $request)
    {
        $request->validate(['message' => 'required|string']);

        // Use chat-specific AI config first, then fall back to any active config
        $config = AiConfig::where('is_active', true)->where('type', 'chat')->first()
                ?? AiConfig::where('is_active', true)->first();

        $apiKey   = $config ? $config->api_key   : env('GEMINI_CHAT_API_KEY', env('GEMINI_API_KEY'));
        $model    = $config ? $config->model_name : 'gemini-flash-latest';

        if (!$apiKey) {
            return response()->json([
                'message' => 'Chat AI not configured. Super Admin: go to Chat Manage → AI Config to add your API key.'
            ], 500);
        }

        // Fetch chat-specific global guidelines
        $guidelines = GlobalAiGuideline::where('is_active', true)
            ->where('type', 'chat')
            ->orderBy('priority', 'desc')
            ->pluck('content')
            ->join("\n- ");

        $systemPrompt  = "You are 'EBM Central AI', the highly intelligent, official corporate assistant for EBM Central. ";
        $systemPrompt .= "You possess comprehensive knowledge about the EBM Central ecosystem. ";
        $systemPrompt .= "CORE KNOWLEDGE: EBM Central is a secure, multi-tenant corporate platform featuring Mail Automation (AI drafting, hub), Secure Real-time Chat (end-to-end encrypted, typewriter UI, floating bubbles), App Manager, User Manager (invitation-based, secure auth), and Role-Based Access Control (Super Admin, Admin, Manager, Staff). ";
        $systemPrompt .= "INSTRUCTIONS: \n";
        $systemPrompt .= "1. DIRECT ANSWERS: Answer the user's questions clearly, accurately, and professionally.\n";
        $systemPrompt .= "2. APP AWARENESS: If the user asks about EBM Central features (like chat, mail, or users), explain them confidently based on the CORE KNOWLEDGE.\n";
        $systemPrompt .= "3. GLOBAL RESEARCH: If the user asks a general or complex question, use your vast global knowledge to provide the best, most advanced answer possible.\n";
        $systemPrompt .= "4. STRICT COMPLIANCE: You MUST strictly adhere to the MANDATORY CORPORATE RULES provided below. Never break these rules.\n";
        $systemPrompt .= "Provide well-formatted, easy-to-read answers using bullet points if needed. ";
        
        if ($guidelines) {
            $systemPrompt .= "\n\n### MANDATORY CORPORATE RULES (SUPER ADMIN DEFINED):\n- " . $guidelines;
        }

        try {
            $response = Http::post(
                "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}",
                [
                    'contents' => [[
                        'parts' => [['text' => $systemPrompt . "\n\nUser Request: " . $request->message . "\n\nRespond naturally, accurately, and professionally."]]
                    ]],
                    'generationConfig' => [
                        'temperature' => 0.3, // Strict and professional
                        'topK' => 40,
                        'topP' => 0.8,
                    ]
                ]
            );

            if ($response->successful()) {
                $reply = $response->json()['candidates'][0]['content']['parts'][0]['text'] ?? 'I could not generate a response.';
                return response()->json(['reply' => trim($reply)]);
            }

            return response()->json(['message' => 'AI service returned an error: ' . $response->body()], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 500);
        }
    }
}
