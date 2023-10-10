package rs.etf.sab.student;

import rs.etf.sab.operations.BuyerOperations;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class vm190224_BuyerOperationsImplementation implements BuyerOperations {

    final Connection connection = DB.getInstance().getConnection();

    @Override
    public int createBuyer(String buyerName, int cityId) {
        final String query = "INSERT INTO kupac(ime, id_grada, stanje_na_racunu) VALUES(?, ?, 0)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, buyerName);
            ps.setInt(2, cityId);
            ps.executeUpdate();
            final ResultSet generatedKeys = ps.getGeneratedKeys();
            if (generatedKeys.next())
                return generatedKeys.getInt(1);
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int setCity(int buyerId, int cityId) {
        final String query = "UPDATE kupac SET id_grada = ? WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, cityId);
            ps.setInt(2, buyerId);
            ps.executeUpdate();
            return 1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public int getCity(int buyerId) {
        final String query = "SELECT id_grada FROM kupac WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, buyerId);
            final ResultSet rs = ps.executeQuery();
            if (rs.next()) {
                return rs.getInt(1);
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public BigDecimal increaseCredit(int buyerId, BigDecimal credit) {
        final String query = "UPDATE kupac SET stanje_na_racunu = stanje_na_racunu + ? WHERE id = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setBigDecimal(1, credit);
            ps.setInt(2, buyerId);
            ps.executeUpdate();
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return null;
        }

        return getCredit(buyerId);
    }

    @Override
    public int createOrder(int buyerId) {
        final String query = "INSERT INTO porudzbina(stanje, id_kupca) " +
                "VALUES('created', ?)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, buyerId);
            ps.executeUpdate();
            final ResultSet generatedKeys = ps.getGeneratedKeys();
            if (generatedKeys.next())
                return generatedKeys.getInt(1);
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        return -1;
    }

    @Override
    public List<Integer> getOrders(int buyerId) {
        final String query = "SELECT id FROM porudzbina WHERE id_kupca = ?";

        final List<Integer> orders = new ArrayList<>();

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, buyerId);
            final ResultSet rs = ps.executeQuery();
            while (rs.next()) {
                orders.add(rs.getInt(1));
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
        return orders;
    }

    @Override
    public BigDecimal getCredit(int buyerId) {
        final String query = "SELECT stanje_na_racunu FROM kupac WHERE id = ?";

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
}
