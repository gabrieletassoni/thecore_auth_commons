module ThecoreAuthCommonsActioncontrollerConcerns
    extend ActiveSupport::Concern
    
    included do
        include HttpAcceptLanguage::AutoLocale
    end
end