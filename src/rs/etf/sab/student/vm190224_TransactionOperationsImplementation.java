package rs.etf.sab.student;

import rs.etf.sab.operations.TransactionOperations;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;

public class vm190224_TransactionOperationsImplementation implements TransactionOperations {

    final Connection connection = DB.getInstance().getConnection();

    @Override
    public BigDecimal getBuyerTransactionsAmmount(int buyerId) {
        final String query = "SELECT SUM(iznos) FROM transakcija WHERE id_kupca = ? AND tip = 'kupac'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, buyerId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public BigDecimal getShopTransactionsAmmount(int shopId) {
        final String query = "SELECT COALESCE(SUM(iznos), 0) FROM transakcija WHERE id_prodavnice = ? AND tip = 'prodavnica'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, shopId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public List<Integer> getTransationsForBuyer(int buyerId) {
        final String query = "SELECT id FROM transakcija WHERE id_kupca = ? AND tip = 'kupac'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, buyerId);
            final ResultSet rs = ps.executeQuery();
            final List<Integer> transactions = new ArrayList<>();
            while (rs.next()) {
                transactions.add(rs.getInt(1));
            }
            return transactions;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public int getTransactionForBuyersOrder(int orderId) {
        final String query = "SELECT id FROM transakcija WHERE id_porudzbine = ? AND tip = 'kupac'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return 0;
    }

    @Override
    public int getTransactionForShopAndOrder(int orderId, int shopId) {
        final String query = "SELECT id FROM transakcija WHERE id_porudzbine = ? AND id_prodavnice = ? AND tip = 'prodavnica'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ps.setInt(2, shopId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return 0;
    }

    @Override
    public List<Integer> getTransationsForShop(int shopId) {
        final String query = "SELECT id FROM transakcija WHERE id_prodavnice = ? AND tip = 'prodavnica'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, shopId);
            final ResultSet rs = ps.executeQuery();
            final List<Integer> transactions = new ArrayList<>();
            while (rs.next()) {
                transactions.add(rs.getInt(1));
            }
            return transactions.size() == 0 ? null : transactions;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public Calendar getTimeOfExecution(int transactionId) {
        final String query = "SELECT vreme_izvrsenja FROM transakcija WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, transactionId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                Calendar calendar = Calendar.getInstance();
                calendar.setTimeInMillis(rs.getDate(1).getTime());
                return calendar;
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public BigDecimal getAmmountThatBuyerPayedForOrder(int orderId) {
        final String query = "SELECT COALESCE(SUM(iznos), 0) FROM transakcija WHERE id_porudzbine = ? AND tip = 'kupac'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public BigDecimal getAmmountThatShopRecievedForOrder(int shopId, int orderId) {
        final String query = "SELECT SUM(iznos) FROM transakcija WHERE id_porudzbine = ? AND id_prodavnice = ? AND tip = 'prodavnica'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, orderId);
            ps.setInt(2, shopId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public BigDecimal getTransactionAmount(int transactionId) {
        final String query = "SELECT iznos FROM transakcija WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, transactionId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return null;
    }

    @Override
    public BigDecimal getSystemProfit() {
        final String query = "SELECT COALESCE(SUM(iznos), 0) FROM transakcija WHERE tip = 'sistem'";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getBigDecimal(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
        return null;
    }
}
