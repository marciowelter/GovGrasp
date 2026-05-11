<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WorkerRun extends Model
{
    protected $fillable = [
        'status',
        'opportunities_fetched',
        'processed_count',
        'opportunities_qualified',
        'error_message',
        'started_at',
        'completed_at',
    ];

    protected $casts = [
        'started_at' => 'datetime',
        'completed_at' => 'datetime',
        'opportunities_fetched' => 'integer',
        'processed_count' => 'integer',
        'opportunities_qualified' => 'integer',
    ];
}
