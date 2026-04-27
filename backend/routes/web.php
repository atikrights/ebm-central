<?php

use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return response()->json(['message' => 'EBM Central API is online.', 'status' => 'L4 Clearance Required']);
});

// Smart Redirect to Frontend Join Page
Route::get('/join/{token}', function ($token) {
    $frontendUrl = env('FRONTEND_URL', 'http://localhost:3000'); 
    return redirect($frontendUrl . '/#/join/' . $token);
});
