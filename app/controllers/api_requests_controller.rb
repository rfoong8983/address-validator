class ApiRequestsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    api_request = ApiRequest.create!(reference_uuid: api_request_params)

    validator = UsStreetMultipleValidator.new(api_request)

    result = validator.run(validation_params)

    respond_to do |format|
      format.json { render json: result }
    end
  end

  def validation_params
    params.require(:addresses)
  end

  def api_request_params
    params.require(:reference_uuid)
  end
end
