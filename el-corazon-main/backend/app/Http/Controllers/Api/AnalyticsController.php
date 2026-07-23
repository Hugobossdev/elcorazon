<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AnalyticsEvent;
use App\Models\Driver;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Reporting pour le panel admin. Le chiffre d'affaires ne compte que les
 * commandes effectivement payées (payment_status = completed).
 */
class AnalyticsController extends Controller
{
    /** Indicateurs clés du tableau de bord. */
    public function dashboard(): JsonResponse
    {
        $paidRevenue = Order::where('payment_status', 'completed')->sum('total');
        $todayRevenue = Order::where('payment_status', 'completed')
            ->whereDate('created_at', today())
            ->sum('total');

        $ordersByStatus = Order::query()
            ->select('status', DB::raw('COUNT(*) as count'))
            ->groupBy('status')
            ->pluck('count', 'status');

        return response()->json([
            'data' => [
                'revenue_total' => round((float) $paidRevenue, 2),
                'revenue_today' => round((float) $todayRevenue, 2),
                'orders_total' => Order::count(),
                'orders_today' => Order::whereDate('created_at', today())->count(),
                'orders_by_status' => $ordersByStatus,
                'clients_total' => User::where('role', 'client')->count(),
                'drivers_online' => Driver::where('is_available', true)->where('status', 'available')->count(),
                'avg_order_value' => round((float) (Order::where('payment_status', 'completed')->avg('total') ?? 0), 2),
            ],
        ]);
    }

    /** Revenu agrégé par jour sur les N derniers jours. */
    public function revenue(Request $request): JsonResponse
    {
        $days = min(max($request->integer('days', 30), 1), 365);

        $rows = Order::query()
            ->where('payment_status', 'completed')
            ->where('created_at', '>=', now()->subDays($days))
            ->select(
                DB::raw("to_char(created_at, 'YYYY-MM-DD') as day"),
                DB::raw('SUM(total) as revenue'),
                DB::raw('COUNT(*) as orders'),
            )
            ->groupBy('day')
            ->orderBy('day')
            ->get();

        return response()->json(['data' => $rows]);
    }

    /** Meilleures ventes (par quantité) sur la période. */
    public function topItems(Request $request): JsonResponse
    {
        $limit = min(max($request->integer('limit', 10), 1), 50);

        $rows = OrderItem::query()
            ->select(
                'menu_item_id',
                'name',
                DB::raw('SUM(quantity) as total_quantity'),
                DB::raw('SUM(total_price) as total_revenue'),
            )
            ->groupBy('menu_item_id', 'name')
            ->orderByDesc('total_quantity')
            ->limit($limit)
            ->get();

        return response()->json(['data' => $rows]);
    }

    /** Journalise un évènement analytics (tout utilisateur authentifié). */
    public function logEvent(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event_type' => ['required', 'string', 'max:255'],
            'event_data' => ['nullable', 'array'],
            'session_id' => ['nullable', 'string', 'max:255'],
        ]);

        $event = AnalyticsEvent::create([
            'user_id' => $request->user()->id,
            'event_type' => $data['event_type'],
            'event_data' => $data['event_data'] ?? [],
            'session_id' => $data['session_id'] ?? null,
        ]);

        return response()->json(['data' => $event], 201);
    }
}
