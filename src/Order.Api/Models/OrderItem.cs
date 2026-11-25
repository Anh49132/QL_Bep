namespace Order.Api.Models;

public sealed class OrderItem
{
    public int Id { get; set; }
    public Guid OrderId { get; set; }
    public Order Order { get; set; } = null!;
    public int MenuItemId { get; set; }
    public MenuItem MenuItem { get; set; } = null!;
    public required string MenuItemName { get; set; }
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }
    public string? Notes { get; set; }
}
