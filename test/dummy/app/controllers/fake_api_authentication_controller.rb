# Stands in for model_driven_api's POST /api/v2/authenticate, which is not in this gem's bundle:
# 200 with the right password, 401 otherwise, as the real one answers.
class FakeApiAuthenticationController < ActionController::API
  def authenticate
    if params.dig(:auth, :password) == "Api-Pass-123!"
      render json: { ok: true }
    else
      render json: { error: "Invalid credentials" }, status: :unauthorized
    end
  end
end
