<?php

namespace App\Http\Controllers\API;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Task;
use Illuminate\Support\Facades\Auth;

class TaskController extends Controller
{
    /**
     * Display a listing of tasks for the current company.
     */
    public function index(Request $request)
    {
        $user = Auth::user();
        
        $query = Task::where('company_id', $user->current_company_id);

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('type')) {
            $query->where('type', $request->type);
        }

        $tasks = $query->with('assignee')->latest()->paginate(15);

        return response()->json([
            'status' => 'success',
            'data' => $tasks
        ]);
    }

    /**
     * Store a newly created task.
     */
    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'type' => 'required|in:income,expense',
            'amount' => 'required|numeric|min:0',
            'status' => 'in:pending,in_progress,completed,cancelled',
            'due_date' => 'nullable|date',
            'project_id' => 'nullable|exists:projects,id',
        ]);

        $user = Auth::user();

        $task = Task::create([
            'company_id' => $user->current_company_id,
            'user_id' => $user->id,
            'project_id' => $request->project_id,
            'name' => $request->name,
            'description' => $request->description,
            'type' => $request->type,
            'amount' => $request->amount,
            'status' => $request->status ?? 'pending',
            'due_date' => $request->due_date,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Task created successfully',
            'data' => $task
        ], 201);
    }

    /**
     * Display combined task summary (income vs expense).
     */
    public function summary()
    {
        $user = Auth::user();

        $income = Task::where('company_id', $user->current_company_id)
            ->where('type', 'income')
            ->where('status', 'completed')
            ->sum('amount');

        $expense = Task::where('company_id', $user->current_company_id)
            ->where('type', 'expense')
            ->where('status', 'completed')
            ->sum('amount');

        return response()->json([
            'status' => 'success',
            'data' => [
                'total_income' => $income,
                'total_expense' => $expense,
                'profit' => $income - $expense,
            ]
        ]);
    }
}
