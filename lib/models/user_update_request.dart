class UserUpdateRequest {
  final String name;
  final String lastName;
  final String secondLastName;

  const UserUpdateRequest({
    required this.name,
    required this.lastName,
    required this.secondLastName,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'last_name': lastName,
    'second_last_name': secondLastName,
  };

  bool get isValid => name.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      secondLastName.trim().isNotEmpty;

  List<String> get validationErrors {
    final errors = <String>[];
    _validateName(name, 'First name', errors);
    _validateName(lastName, 'Last name', errors);
    _validateName(secondLastName, 'Second last name', errors);
    return errors;
  }

  void _validateName(String value, String fieldName, List<String> errors) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      errors.add('$fieldName is required');
    } else if (trimmed.length < 3) {
      errors.add('$fieldName must be at least 3 characters long');
    } else if (trimmed.length > 100) {
      errors.add('$fieldName is too long (maximum 100 characters)');
    } else if (!_isValidName(trimmed)) {
      errors.add('$fieldName can only contain letters and spaces');
    }
  }

  bool _isValidName(String name) => RegExp(
    r"^[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ\s'.-]+$"
  ).hasMatch(name);
}