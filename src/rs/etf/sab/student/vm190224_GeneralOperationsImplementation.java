package rs.etf.sab.student;

import rs.etf.sab.operations.GeneralOperations;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.SQLException;
import java.util.Calendar;

public class vm190224_GeneralOperationsImplementation implements GeneralOperations {

    private static Calendar time;
    final Connection connection = DB.getInstance().getConnection();

    private void tick(int days) {
        final String query = "{ CALL SP_TIME_ELAPSED(?) }";

        try (CallableStatement cs = connection.prepareCall(query)) {
            cs.setInt(1, days);
            cs.execute();
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
    }

    @Override
    public void setInitialTime(Calendar calendar) {
        time = Calendar.getInstance();
        time.clear();
        time.setTimeInMillis(calendar.getTimeInMillis());
    }

    @Override
    public Calendar time(int days) {
        time.add(Calendar.DAY_OF_MONTH, days);
        tick(days);
        return time;
    }

    @Override
    public Calendar getCurrentTime() {
        return time;
    }

    @Override
    public void eraseAll() {
        final String query =
                        "DISABLE TRIGGER ALL ON DATABASE;\n;" +
                        "EXEC sp_MSForEachTable 'ALTER TABLE ? NOCHECK CONSTRAINT ALL';\n" +
                        "EXEC sp_MSForEachTable 'DELETE FROM ?';\n" +
                        "EXEC sp_MSForEachTable 'ALTER TABLE ? CHECK CONSTRAINT ALL';\n" +
                        "ENABLE TRIGGER ALL ON DATABASE;\n";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.executeUpdate();
            connection.commit();
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
    }
}