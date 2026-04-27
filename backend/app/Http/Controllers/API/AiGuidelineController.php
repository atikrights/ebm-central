<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use App\Models\GlobalAiGuideline;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class AiGuidelineController extends Controller
{
    public function index(Request $request)
    {
        $query = GlobalAiGuideline::latest();
        if ($request->has('type')) {
            $query->where('type', $request->type);
        }
        return response()->json([
            'status' => 'success',
            'data' => $query->get()
        ]);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'guide_id' => 'required|string|max:32|unique:global_ai_guidelines',
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'type' => 'required|in:mail,chat',
            'short_description' => 'nullable|string',
            'topic' => 'nullable|string',
            'topic_description' => 'nullable|string',
            'guide_policy' => 'nullable|string',
            'guide_note' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['status' => 'error', 'errors' => $validator->errors()], 422);
        }

        $guideline = GlobalAiGuideline::create($request->all());

        return response()->json([
            'status' => 'success',
            'message' => 'Guideline created successfully',
            'data' => $guideline
        ]);
    }

    public function show(GlobalAiGuideline $ai_guideline)
    {
        return response()->json([
            'status' => 'success',
            'data' => $ai_guideline
        ]);
    }

    public function update(Request $request, GlobalAiGuideline $ai_guideline)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'short_description' => 'nullable|string',
            'topic' => 'nullable|string',
            'topic_description' => 'nullable|string',
            'guide_policy' => 'nullable|string',
            'guide_note' => 'nullable|string',
        ]);

        if ($validator->fails()) {
            return response()->json(['status' => 'error', 'errors' => $validator->errors()], 422);
        }

        $ai_guideline->update($request->all());

        return response()->json([
            'status' => 'success',
            'message' => 'Guideline updated successfully',
            'data' => $ai_guideline
        ]);
    }

    public function destroy(GlobalAiGuideline $ai_guideline)
    {
        $ai_guideline->delete();

        return response()->json([
            'status' => 'success',
            'message' => 'Guideline deleted successfully'
        ]);
    }

    public function toggleStatus(GlobalAiGuideline $ai_guideline)
    {
        $ai_guideline->is_active = !$ai_guideline->is_active;
        $ai_guideline->save();

        return response()->json([
            'status' => 'success',
            'message' => 'Status updated',
            'is_active' => $ai_guideline->is_active
        ]);
    }
}
