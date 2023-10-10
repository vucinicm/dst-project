package rs.etf.sab.student;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;

public class DB {

    private static final String username = "sa";
    private static final String password = "123";
    private static final String databaseName = "OnlineProdajaArtikala";
    private static final int port = 1433;
    private static final String server = "localhost";

    private static final String connectionUrlTemplate =
            "jdbc:sqlserver://%s:%s;encrypt=true;trustServerCertificate=true;databaseName=%s;user=%s;password=%s;";

    private static final String connectionUrl =
            String.format(connectionUrlTemplate, server, port, databaseName, username, password);

    private static DB instance = null;

    private Connection connection = null;

    private DB() {
        try {
            connection = DriverManager.getConnection(connectionUrl);
        } catch (SQLException exception) {
            System.out.println(exception.getMessage());
        }
    }

    public static DB getInstance() {
        if (instance == null) {
            instance = new DB();
        }
        return instance;
    }

    public Connection getConnection() {
        return connection;
    }

}
