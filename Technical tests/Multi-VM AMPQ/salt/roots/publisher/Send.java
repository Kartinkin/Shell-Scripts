import com.rabbitmq.client.ConnectionFactory;
import com.rabbitmq.client.Connection;
import com.rabbitmq.client.Channel;
import com.rabbitmq.client.MessageProperties;

public class Send {
  private static final String QUEUE_NAME = "technical_test";
  private static final String MQ_SERVER = "mq-server";

  public static void main(String[] argv) throws Exception {
    ConnectionFactory factory = new ConnectionFactory();
    factory.setHost(MQ_SERVER);
    Connection connection = factory.newConnection();
    Channel channel = connection.createChannel();

    channel.queueDeclare(QUEUE_NAME, true, false, false, null);

    String message = Message(argv);

    channel.basicPublish( "", QUEUE_NAME,
            MessageProperties.PERSISTENT_TEXT_PLAIN,
            message.getBytes());
    System.out.println("Sent '" + message + "'");

    channel.close();
    connection.close();
  }
  
  private static String Message(String[] strings){
    if (strings.length < 1)
        return "1";
    else
        return strings[0];
  }
      
}