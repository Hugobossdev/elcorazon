<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Order\CancelOrderRequest;
use App\Http\Requests\Order\StoreOrderRequest;
use App\Http\Requests\Order\UpdateOrderStatusRequest;
use App\Http\Resources\OrderResource;
use App\Models\Order;
use App\Services\Order\OrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class OrderController extends Controller
{
    public function __construct(private readonly OrderService $orders) {}

    /** Liste filtrée selon le rôle de l'utilisateur. */
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();
        $query = Order::query()->with('items')->latest('created_at');

        if ($user->isClient()) {
            $query->where('user_id', $user->id);
        } elseif ($user->isDriver()) {
            $query->where('delivery_person_id', $user->id);
        }
        // admin : accès à toutes les commandes

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        return OrderResource::collection(
            $query->paginate($request->integer('per_page', 20))
        );
    }

    public function show(Request $request, Order $order): OrderResource
    {
        $this->authorize('view', $order);

        return new OrderResource(
            $order->load(['items', 'statusUpdates', 'activeDelivery', 'deliveryPerson'])
        );
    }

    /**
     * Crée une commande. Les totaux sont recalculés côté serveur par le
     * service (jamais fait confiance au client).
     */
    public function store(StoreOrderRequest $request): JsonResponse
    {
        $this->authorize('create', Order::class);

        $order = $this->orders->create($request->user(), $request->validated());

        return (new OrderResource($order->load('items')))
            ->response()
            ->setStatusCode(201);
    }

    /** Transition de statut (admin ou livreur assigné). */
    public function updateStatus(UpdateOrderStatusRequest $request, Order $order): OrderResource
    {
        $this->authorize('update', $order);

        $data = $request->validated();
        $order = $this->orders->changeStatus(
            $order,
            $data['status'],
            $data['notes'] ?? null,
            $request->user(),
        );

        return new OrderResource($order);
    }

    public function cancel(CancelOrderRequest $request, Order $order): OrderResource
    {
        $this->authorize('cancel', $order);

        $order = $this->orders->cancel(
            $order,
            $request->validated()['reason'] ?? null,
            $request->user(),
        );

        return new OrderResource($order);
    }
}
