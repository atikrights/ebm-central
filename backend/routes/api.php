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

    // Governance & Security Mesh
    Route::post('governance/invite', [\App\Http\Controllers\API\GovernanceController::class, 'generateInvitation']);
    Route::get('governance/users', [\App\Http\Controllers\API\GovernanceController::class, 'systemUsers']);
});
