<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\API\AuthController;
use App\Http\Controllers\API\CompanyController;
use App\Http\Controllers\API\DepartmentController;
use App\Http\Controllers\API\ProjectController;
use App\Http\Controllers\API\TaskController;
use App\Http\Controllers\API\FinanceController;
use App\Http\Controllers\API\AuditLogController;
use App\Http\Controllers\API\AiGuidelineController;

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
Route::post('/governance/verify-keys', [AuthController::class, 'verifyKeys']);
Route::post('/register', [AuthController::class, 'register']);

// No demo routes in production.

// Invitation Validation (Must be public for registration flow)
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

    // Chat (Encrypted & Synced)
    Route::get('chats', [\App\Http\Controllers\API\ChatController::class, 'index']);
    Route::post('chats', [\App\Http\Controllers\API\ChatController::class, 'store']);
    Route::delete('chats/clear', [\App\Http\Controllers\API\ChatController::class, 'clear']);
    Route::post('chat/ai/generate', [\App\Http\Controllers\API\ChatController::class, 'generateAiReply']);

    // Secure Database Vault
    Route::get('security/databases', [\App\Http\Controllers\API\DatabaseController::class, 'index']);
    Route::post('security/databases', [\App\Http\Controllers\API\DatabaseController::class, 'store']);
    Route::delete('security/databases/{id}', [\App\Http\Controllers\API\DatabaseController::class, 'destroy']);
    Route::get('security/system-status', [\App\Http\Controllers\API\DatabaseController::class, 'systemStatus']);

    // Central Storage Vault
    Route::get('storage/files', [\App\Http\Controllers\API\StorageController::class, 'listFiles']);
    Route::post('storage/upload', [\App\Http\Controllers\API\StorageController::class, 'uploadFile']);
    Route::delete('storage/delete', [\App\Http\Controllers\API\StorageController::class, 'deleteFile']);

    // ── Security Audit Logs (Super Admin Only) ───────────────────────────
    Route::get('governance/audit-logs', [AuditLogController::class, 'index']);
    Route::get('governance/audit-logs/stats', [AuditLogController::class, 'stats']);

    // ── User Management & Governance (Super Admin Only) ──────────────────
    Route::post('/users/manual-create', [AuthController::class, 'manualCreate']);
    Route::post('governance/invite', [\App\Http\Controllers\API\GovernanceController::class, 'generateInvitation']);
    Route::get('governance/users', [\App\Http\Controllers\API\GovernanceController::class, 'systemUsers']);
    Route::put('governance/users/{id}', [\App\Http\Controllers\API\GovernanceController::class, 'updateUser']);
    Route::put('governance/users/{id}/role', [\App\Http\Controllers\API\GovernanceController::class, 'updateRole']);
    Route::delete('governance/users/{id}', [\App\Http\Controllers\API\GovernanceController::class, 'deleteUser']);

    // ── Workplace Mail System ───────────────────────────────────────────
    Route::get('mail/settings', [\App\Http\Controllers\API\MailController::class, 'getSettings']);
    Route::post('mail/settings', [\App\Http\Controllers\API\MailController::class, 'storeSettings']);
    Route::post('mail/test', [\App\Http\Controllers\API\MailController::class, 'testConnection']);
    Route::get('mail/inbox', [\App\Http\Controllers\API\MailController::class, 'getInbox']);
    Route::post('mail/send', [\App\Http\Controllers\API\MailController::class, 'sendMail']);

    // Mail Automation & AI
    Route::get('mail/automations', [\App\Http\Controllers\API\MailAutomationController::class, 'index']);
    Route::post('mail/automations', [\App\Http\Controllers\API\MailAutomationController::class, 'store']);
    Route::delete('mail/automations/{id}', [\App\Http\Controllers\API\MailAutomationController::class, 'destroy']);
    Route::post('mail/automations/{id}/toggle', [\App\Http\Controllers\API\MailAutomationController::class, 'toggle']);
    Route::post('mail/ai/generate', [\App\Http\Controllers\API\MailAutomationController::class, 'generateAiContent']);

    // ── AI Guidelines Management (Super Admin) ───────────────────────────
    Route::apiResource('governance/ai-guidelines', AiGuidelineController::class);
    Route::post('governance/ai-guidelines/{ai_guideline}/toggle', [AiGuidelineController::class, 'toggleStatus']);
});

