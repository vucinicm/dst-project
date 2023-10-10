package rs.etf.sab.student;

import rs.etf.sab.operations.CityOperations;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

public class vm190224_CityOperationsImplementation implements CityOperations {

    final Connection connection = DB.getInstance().getConnection();

    @Override
    public int createCity(String name) {
        String query = "SELECT id FROM grad WHERE naziv = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setString(1, name);
            final ResultSet resultSet = ps.executeQuery();
            if (resultSet.next())
                return -1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return -1;
        }

        query = "INSERT INTO grad(naziv) VALUES(?)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setString(1, name);
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
    public List<Integer> getCities() {
        final String query = "SELECT id FROM grad";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            final ResultSet resultSet = ps.executeQuery();
            final List<Integer> result = new ArrayList<>();
            while (resultSet.next()) {
                result.add(resultSet.getInt(1));
            }
            return result;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
        return null;
    }

    @Override
    public int connectCities(int cityId1, int cityId2, int distance) {
        String query = "SELECT id_grad_1 FROM povezanost WHERE id_grad_1 = ? AND id_grad_2 = ? OR id_grad_1 = ? AND id_grad_2 = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, cityId1);
            ps.setInt(2, cityId2);
            ps.setInt(3, cityId2);
            ps.setInt(4, cityId1);
            final ResultSet resultSet = ps.executeQuery();
            if (resultSet.next())
                return -1;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return -1;
        }

        query = "INSERT INTO povezanost(id_grad_1, id_grad_2, razdaljina) VALUES(?, ?, ?)";

        try (PreparedStatement ps = connection.prepareStatement(query, PreparedStatement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, cityId1);
            ps.setInt(2, cityId2);
            ps.setInt(3, distance);
            ps.executeUpdate();
            final ResultSet generatedKeys = ps.getGeneratedKeys();
            if (generatedKeys.next())
                return generatedKeys.getInt(1);
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return -1;
        }

        return -1;
    }

    @Override
    public List<Integer> getConnectedCities(int cityId) {
        final String query = "SELECT id_grad_2 FROM povezanost WHERE id_grad_1 = ? UNION "
                + "SELECT id_grad_1 FROM povezanost WHERE id_grad_2 = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, cityId);
            ps.setInt(2, cityId);
            final ResultSet resultSet = ps.executeQuery();
            final List<Integer> result = new ArrayList<>();
            while (resultSet.next()) {
                result.add(resultSet.getInt(1));
            }
            return result;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return null;
        }
    }

    @Override
    public List<Integer> getShops(int cityId) {
        final String query = "SELECT id FROM prodavnica WHERE id_grada = ?";

        try (PreparedStatement ps = connection.prepareStatement(query)) {
            ps.setInt(1, cityId);
            ps.execute();
            final ResultSet resultSet = ps.getResultSet();
            final List<Integer> result = new ArrayList<>();
            while (resultSet.next()) {
                result.add(resultSet.getInt(1));
            }
            return result;
        } catch (SQLException e) {
            System.out.println(e.getMessage());
            return null;
        }
    }
}
