<?php

namespace App\Http\Controllers;

use App\Models\Opportunity;
use App\Models\WorkerRun;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class OpportunityController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $query = Opportunity::query()->latest('created_at');

        if ($status = $request->query('status')) {
            $query->where('status', $status);
        }

        if ($search = $request->query('search')) {
            $query->search($search);
        }

        if ($framework = $request->query('framework')) {
            $query->where('framework', $framework);
        }

        $perPage = min((int) $request->query('per_page', 20), 100);

        return response()->json($query->paginate($perPage));
    }

    public function show(Opportunity $opportunity): JsonResponse
    {
        return response()->json($opportunity);
    }

    public function stats(): JsonResponse
    {
        return response()->json([
            'total' => Opportunity::count(),
            'qualified' => Opportunity::where('status', 'qualified')->count(),
            'rejected' => Opportunity::where('status', 'rejected')->count(),
            'new' => Opportunity::where('status', 'new')->count(),
            'today' => Opportunity::whereDate('created_at', today())->count(),
            'frameworks' => Opportunity::whereNotNull('framework')
                ->distinct()
                ->pluck('framework')
                ->sort()
                ->values(),
        ]);
    }

    public function deleteAll(): JsonResponse
    {
        DB::transaction(function (): void {
            Opportunity::query()->delete();
            WorkerRun::query()->delete();
        });

        return response()->json([
            'status' => 'ok',
            'message' => 'All opportunities and worker runs were deleted.',
        ]);
    }
}
