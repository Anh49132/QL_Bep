namespace Order.Api.Models;

public sealed class Order
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public required string Code { get; set; }
    public Guid TableSessionId { get; set; }
    public int TableNumber { get; set; }
    public TableSession TableSession { get; set; } = null!;
    public required string CustomerCode { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public OrderStatus Status { get; set; } = OrderStatus.Pending;
    public string? Notes { get; set; }
    public decimal Total { get; set; }
    public List<OrderItem> Items { get; set; } = [];
}
