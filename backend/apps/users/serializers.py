from rest_framework import serializers
from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password


class UserProfileSerializer(serializers.Serializer):
    profile_image = serializers.SerializerMethodField()
    city = serializers.CharField(max_length=100, required=False, allow_blank=True)
    state = serializers.CharField(max_length=100, required=False, allow_blank=True)
    country = serializers.CharField(max_length=100, required=False, allow_blank=True)
    street = serializers.CharField(max_length=255, required=False, allow_blank=True)
    birth_date = serializers.DateField(required=False, allow_null=True)
    phone_number = serializers.CharField(required=False, allow_blank=True)
    pin_color = serializers.CharField(max_length=7, required=False)
    pin_style = serializers.ChoiceField(
        choices=["teardrop", "circle", "square", "triangle", "diamond"], required=False
    )
    pin_icon_type = serializers.ChoiceField(
        choices=["none", "emoji", "initials", "picture"], required=False
    )
    pin_emoji = serializers.CharField(
        max_length=10, required=False, allow_null=True, allow_blank=True
    )
    distance_unit = serializers.ChoiceField(choices=["metric", "imperial"], required=False)

    def get_profile_image(self, obj):
        from apps.common.storage import upload_url

        return upload_url(getattr(obj, "profile_image", None), self.context.get("request"))


class RegisterSerializer(serializers.ModelSerializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)
    first_name = serializers.CharField(required=False, allow_blank=True)
    last_name = serializers.CharField(required=False, allow_blank=True)
    # Honeypot field
    first_name_hp = serializers.CharField(required=False, allow_blank=True, write_only=True)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'password_confirm', 'first_name', 'last_name', 'first_name_hp')

    def validate(self, attrs):
        if attrs.get('first_name_hp'):
            # If honeypot is filled, it's a bot.
            # We raise a generic error to not reveal it's a honeypot.
            raise serializers.ValidationError({"detail": "Invalid request."})

        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        
        if User.objects.filter(email=attrs['email']).exists():
            raise serializers.ValidationError({"email": "A user with this email already exists."})
        
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        validated_data.pop('first_name_hp', None)
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        return user


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)


class PasswordResetConfirmSerializer(serializers.Serializer):
    token = serializers.CharField(required=True)
    password = serializers.CharField(write_only=True, required=True, validators=[validate_password])
    password_confirm = serializers.CharField(write_only=True, required=True)

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError({"password": "Passwords do not match."})
        return attrs
