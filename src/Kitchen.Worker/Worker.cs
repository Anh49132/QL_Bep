namespace Kitchen.Worker;

public sealed class Worker(ILogger<Worker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        logger.LogInformation("Kitchen.Worker đã khởi động. Tuần 1 chưa kết nối RabbitMQ hoặc database.");

        try
        {
            await Task.Delay(Timeout.Infinite, stoppingToken);
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            logger.LogInformation("Kitchen.Worker đã nhận yêu cầu dừng.");
        }
    }
}
