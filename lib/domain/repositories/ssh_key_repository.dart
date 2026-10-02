import '../models/ssh_key_model.dart';

abstract class SshKeyRepository {
  Future<List<SshKeyModel>> getKeys();
  Future<SshKeyModel?> getKey(String id);
  Future<void> saveKey(
    SshKeyModel key,
    String privateKeyPem, {
    String? passphrase,
  });
  Future<void> deleteKey(String id);
}
