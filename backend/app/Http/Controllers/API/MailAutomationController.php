<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\MailAutomation;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class MailAutomationController extends Controller
{
    public function index(Request $request)
    {
        return response()->json(MailAutomation::where('user_id', $request->user()->id)->get());
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required',
            'to' => 'required',
            'subject' => 'required',
            'body' => 'required',
            'trigger_type' => 'required',
        ]);

        $automation = MailAutomation::create([
            'user_id' => $request->user()->id,
            'name' => $request->name,
            'to' => $request->to,
            'subject' => $request->subject,
            'body' => $request->body,
            'trigger_type' => $request->trigger_type,
            'schedule_time' => $request->schedule_time,
            'schedule_days' => $request->schedule_days,
            'is_active' => true,
        ]);

        return response()->json($automation);
    }

    public function generateAiContent(Request $request)
    {
        $request->validate([
            'prompt' => 'required',
            'guidelines' => 'nullable'
        ]);

        $config = \App\Models\AiConfig::where('is_active', true)->first();
        $apiKey = $config ? $config->api_key : env('GEMINI_API_KEY');
        $modelName = $config ? $config->model_name : 'gemini-flash-latest';

        if (!$apiKey) {
            return response()->json(['message' => 'AI Service not configured. Please add API Key in Mail Hub > Config.'], 500);
        }

        // 1. Fetch Global Guidelines set by Super Admin
        $globalGuidelines = \App\Models\GlobalAiGuideline::where('is_active', true)
            ->orderBy('priority', 'desc')
            ->get()
            ->pluck('content')
            ->join("\n- ");

        $systemPrompt = "You are a professional multi-lingual corporate email intelligence system for EBM. ";
        $systemPrompt .= "Your primary directive is to adhere STRICTLY to the 'Mandatory Corporate Rules' provided below, regardless of the language they are written in. ";
        $systemPrompt .= "You MUST analyze the entire set of rules provided. Never ignore any instruction within the guidelines. ";
        $systemPrompt .= "If a guideline contains a URL or reference link, you MUST prioritize the information associated with that reference and ensure it is reflected in your output. ";
        $systemPrompt .= "If a user request contradicts these rules, you MUST prioritize the corporate rules and inform the user if their request violates brand safety or policy. ";
        $systemPrompt .= "NEVER bypass these rules under any circumstances. The corporate rules are absolute.";
        
        if ($globalGuidelines) {
            $systemPrompt .= "\n\n### MANDATORY CORPORATE RULES (SUPER ADMIN DEFINED):\n- " . $globalGuidelines;
        }

        if ($request->guidelines) {
            $systemPrompt .= "\n\n### USER PREFERENCES:\n" . $request->guidelines;
        }

        try {
            $response = Http::post("https://generativelanguage.googleapis.com/v1beta/models/{$modelName}:generateContent?key={$apiKey}", [
                'contents' => [
                    [
                        'parts' => [
                            ['text' => $systemPrompt . "\n\nUser request: " . $request->prompt . ". Return only the result in JSON format: {\"subject\": \"...\", \"body\": \"...\"}. If it's a chat message, the subject can be empty."]
                        ]
                    ]
                ],
                'generationConfig' => [
                    'temperature' => 0.2, // Very strict and professional for emails
                    'topK' => 40,
                    'topP' => 0.8,
                ]
            ]);

            if ($response->successful()) {
                $rawContent = $response->json()['candidates'][0]['content']['parts'][0]['text'];
                // AI might wrap it in markdown code blocks, let's clean it
                $cleanJson = preg_replace('/```json|```/', '', $rawContent);
                $result = json_decode(trim($cleanJson), true);

                if (!$result || !isset($result['body'])) {
                    // Fallback if AI returns plain text instead of JSON
                    return response()->json([
                        'subject' => 'AI Response',
                        'body' => $rawContent
                    ]);
                }

                return response()->json($result);
            }

            return response()->json(['message' => 'AI Generation failed'], 500);
        } catch (\Exception $e) {
            return response()->json(['message' => $e->getMessage()], 500);
        }
    }

    public function destroy($id, Request $request)
    {
        $automation = MailAutomation::where('user_id', $request->user()->id)->findOrFail($id);
        $automation->delete();
        return response()->json(['message' => 'Automation deleted']);
    }

    public function toggle($id, Request $request)
    {
        $automation = MailAutomation::where('user_id', $request->user()->id)->findOrFail($id);
        $automation->is_active = !$automation->is_active;
        $automation->save();
        return response()->json($automation);
    }
}
