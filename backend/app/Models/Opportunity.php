<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Opportunity extends Model
{
    use HasFactory;
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
        $likeOperator = $query->getConnection()->getDriverName() === 'sqlite' ? 'like' : 'ilike';
        return $query->where(function (Builder $q) use ($term, $likeOperator): void {
            $q->where('title', $likeOperator, "%{$term}%")
                ->orWhere('buyer_name', $likeOperator, "%{$term}%")
                ->orWhere('description', $likeOperator, "%{$term}%");
        });
    }
}
