<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\CompanyController;
use App\Http\Controllers\API\DepartmentController;
use App\Http\Controllers\API\ProjectController;
use App\Http\Controllers\API\TaskController;
use App\Http\Controllers\API\FinanceController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

// Public routes
Route::post('/login', [AuthController::class, 'login']);
Route::post('/register', [AuthController::class, 'register']);
Route::post('/users/manual-create', [AuthController::class, 'manualCreate']);

// Temporary Setup Route (Delete after testing)
Route::get('/setup-demo', function() {
    \App\Models\User::truncate();
    \App\Models\Invitation::truncate();
    
    \App\Models\User::create([
        'name' => 'Super Admin',
        'email' => 'superadmin@ebfic.store',
        'password' => \Illuminate\Support\Facades\Hash::make('password123'),
        'role' => 'super_admin'
    ]);

    \App\Models\User::create([
        'name' => 'Admin User',
        'email' => 'admin@ebfic.store',
        'password' => \Illuminate\Support\Facades\Hash::make('password123'),
        'role' => 'admin'
    ]);

    return response()->json(['message' => 'Demo setup complete. Previous users removed.']);
});

// Invitation & Governance (Public for local testing and registration flow)
Route::post('governance/invite', [\App\Http\Controllers\API\GovernanceController::class, 'generateInvitation']);
Route::get('governance/invite/validate/{token}', [\App\Http\Controllers\API\GovernanceController::class, 'validateInvitation']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);

    // Company Management
    Route::apiResource('companies', CompanyController::class);
    Route::post('companies/switch', [CompanyController::class, 'switchCompany']);

    // Departments
    Route::apiResource('departments', DepartmentController::class);

    // Projects
    Route::apiResource('projects', ProjectController::class);
    Route::get('projects/{project}/stats', [ProjectController::class, 'stats']);

    // Tasks (Income/Expense/Tasks)
    Route::apiResource('tasks', TaskController::class);
    Route::get('tasks/summary', [TaskController::class, 'summary']);

    // Finance & Analytics
    Route::get('finance/dashboard', [FinanceController::class, 'dashboard']);
    Route::get('finance/transactions', [FinanceController::class, 'transactions']);
    
    // Team Management
    Route::get('team', [AuthController::class, 'teamMembers']);
    Route::post('team/invite', [AuthController::class, 'inviteMember']);

    // Chat
    Route::get('messages', [TaskController::class, 'getMessages']); // Placeholder
    Route::post('messages', [TaskController::class, 'sendMessage']);

    Route::get('governance/users', [\App\Http\Controllers\API\GovernanceController::class, 'systemUsers']);

    // Secure Database Vault
    Route::get('security/databases', [\App\Http\Controllers\API\DatabaseController::class, 'index']);
    Route::post('security/databases', [\App\Http\Controllers\API\DatabaseController::class, 'store']);
    Route::delete('security/databases/{id}', [\App\Http\Controllers\API\DatabaseController::class, 'destroy']);
    Route::get('security/system-status', [\App\Http\Controllers\API\DatabaseController::class, 'systemStatus']);
});
