import 'package:flutter_test/flutter_test.dart';
import 'package:mine_wadhwani/data/models/auth/user_model.dart';

void main() {
  const server = {
    '_id': '1', 'name': 'A', 'email': 'a@x.com', 'mobilenumber': '9',
    'role': 'MINE_ADMIN', 'mine_role': 'Assistant Mine Manager',
  };

  test('login JSON keeps job title in role and access level in accessRole', () {
    final u = UserModel.fromJson(server, token: 't');
    expect(u.role, 'Assistant Mine Manager');
    expect(u.accessRole, 'MINE_ADMIN');
    expect(u.isAdmin, isTrue);
  });

  test('cached JSON round-trip keeps admin access', () {
    final cached = UserModel.fromJson(UserModel.fromJson(server, token: 't').toJson());
    expect(cached.isAdmin, isTrue);
  });

  test('supervisor is not admin', () {
    final u = UserModel.fromJson({...server, 'role': 'SUPERVISOR'});
    expect(u.isAdmin, isFalse);
  });
}
