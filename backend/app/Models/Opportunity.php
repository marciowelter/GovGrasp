<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

class Opportunity extends Model
{
    protected $fillable = [
        'ocid',
        'title',
        'description',
        'buyer_name',
        'value_amount',
        'value_currency',
        'deadline',
        'published_at',
        'source',
        'status',
        'qualified',
        'ai_score',
        'ai_reasoning',
        'framework',
        'raw_s3_key',
    ];

    protected $casts = [
        'deadline' => 'datetime',
        'published_at' => 'datetime',
        'qualified' => 'boolean',
        'value_amount' => 'decimal:2',
        'ai_score' => 'integer',
    ];

    public function scopeQualified(Builder $query): Builder
    {
        return $query->where('status', 'qualified');
    }

    public function scopeSearch(Builder $query, string $term): Builder
    {
        return $query->where(function (Builder $q) use ($term): void {
            $q->where('title', 'ilike', "%{$term}%")
                ->orWhere('buyer_name', 'ilike', "%{$term}%")
                ->orWhere('description', 'ilike', "%{$term}%");
        });
    }
}
