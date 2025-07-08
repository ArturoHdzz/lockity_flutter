class UserUpdateRequest {
  final String name;
  final String lastName;
  final String secondLastName;
  final String email;

  const UserUpdateRequest({
    required this.name,
    required this.lastName,
    required this.secondLastName,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'last_name': lastName,
    'second_last_name': secondLastName,
    'email': email,
  };

  bool get isValid => name.trim().isNotEmpty &&
      lastName.trim().isNotEmpty &&
      secondLastName.trim().isNotEmpty &&
      email.trim().isNotEmpty &&
      _isValidEmail(email);

  List<String> get validationErrors {
    final errors = <String>[];
    
    _validateName(name, 'First name', errors);
    _validateName(lastName, 'Last name', errors);
    _validateName(secondLastName, 'Second last name', errors);
    _validateEmail(email, errors);
    
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

  void _validateEmail(String value, List<String> errors) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      errors.add('Email is required');
    } else if (!_isValidEmail(trimmed)) {
      errors.add('Please enter a valid email address');
    }
  }

  bool _isValidName(String name) => RegExp(
    r"^[a-zA-ZàáâäãåąčćęèéêëėįìíîïłńòóôöõøùúûüųūÿýżźñçčšžÀÁÂÄÃÅĄĆČĖĘÈÉÊËÌÍÎÏĮŁŃÒÓÔÖÕØÙÚÛÜŲŪŸÝŻŹÑßÇŒÆČŠŽ\s'.-]+$"
  ).hasMatch(name);

  bool _isValidEmail(String email) => RegExp(
    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$'
  ).hasMatch(email);
}