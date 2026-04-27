<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class GlobalAiGuideline extends Model
{
    use HasFactory;

    protected $fillable = [
        'guide_id',
        'title',
        'short_description',
        'topic',
        'topic_description',
        'content',
        'guide_policy',
        'guide_note',
        'is_active',
        'priority'
    ];

    protected $casts = [
        'is_active' => 'boolean',
    ];
}
