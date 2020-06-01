module Permissions
  class BasePermission
    def permit?(controller, action, resource = nil)
      # may also want to validate that the instance variables @permit_all
      # and @permited_actions are defined, prior to this...
      permited = @permit_all || @permited_actions[[controller.to_s, action.to_s]]
      permited && (permited == true || resource && permited.call(resource))
    end

    def permit_all
      @permit_all = true
    end

    def permit(controllers,actions, &block)
      @permited_actions ||= {}
      # wrapping in array permits for the acceptance of an array or a single string object
      Array(controllers).each do |controller|
        Array(actions).each do |action|
          @permited_actions[[controller.to_s, action.to_s]] = block || true
        end
      end
    end

    def permit_param(resources,attributes)
      @permitted_params ||= {}
      # wrapping in array permits for the acceptance of an array or a single string object
      Array(resources).each do |resource|
        @permitted_params[resource.to_s] ||= []
        @permitted_params[resource.to_s] += Array(attributes).map(&:to_s)
      end
    end

    def permit_param?(resource,attribute)
      if(@permit_all)
        true
      elsif( @permitted_params && @permitted_params[resource.to_s])
        @permitted_params[resource.to_s].include? attribute.to_s
      end
    end

    def permit_params!(params)
      if( @permit_all )
        params.permit!
      elsif( @permited_params )
        @permited_params.each do |resource, attributes|
          if( params[resource].respond_to? :permit )
            params[resource] = params[resource].permit(*attributes)
          end
        end
      end
    end
  end
end
