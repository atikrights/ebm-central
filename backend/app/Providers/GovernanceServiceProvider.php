<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use App\Services\DatabaseVaultService;

class GovernanceServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Bind the Database Vault Service as a singleton so it can be used globally
        $this->app->singleton(DatabaseVaultService::class, function ($app) {
            return new DatabaseVaultService();
        });
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Enforce strict HTTPS in production for cross-platform security
        if ($this->app->environment('production')) {
            \URL::forceScheme('https');
        }
    }
}
