require 'sprockets/base'
require 'sprockets/charset_normalizer'
require 'sprockets/context'
require 'sprockets/directive_processor'
require 'sprockets/index'
require 'sprockets/safety_colons'

require 'hike'
require 'logger'
require 'pathname'
require 'tilt'

module Sprockets
  class Environment < Base
    # `Environment` should initialized with your application's root
    # directory. This should be the same as your Rails or Rack root.
    #
    #     env = Environment.new(Rails.root)
    #
    def initialize(root = ".")
      @trail = Hike::Trail.new(root)

      self.logger = Logger.new($stderr)
      self.logger.level = Logger::FATAL

      # Create a safe `Context` subclass to mutate
      @context_class = Class.new(Context)

      # Set MD5 as the default digest
      require 'digest/md5'
      @digest_class = ::Digest::MD5
      @version = ''

      @static_root = nil

      @engines = Sprockets.engines
      @trail.extensions.replace(engine_extensions)

      @mime_types = {}
      @preprocessors     = Hash.new { |h, k| h[k] = [] }
      @postprocessors    = Hash.new { |h, k| h[k] = [] }
      @bundle_processors = Hash.new { |h, k| h[k] = [] }

      register_mime_type 'text/css', '.css'
      register_mime_type 'application/javascript', '.js'

      register_preprocessor 'text/css', DirectiveProcessor
      register_preprocessor 'application/javascript', DirectiveProcessor

      register_postprocessor 'application/javascript', SafetyColons
      register_bundle_processor 'text/css', CharsetNormalizer

      expire_index!

      yield self if block_given?
    end

    # Returns a cached version of the environment.
    #
    # All its file system calls are cached which makes `index` much
    # faster. This behavior is ideal in production since the file
    # system only changes between deploys.
    def index
      Index.new(self)
    end

    # Cache `find_asset` calls
    def find_asset(path, options = {})
      # Ensure inmemory cached assets are still fresh on every lookup
      if (asset = @assets[path.to_s]) && asset.fresh?
        asset
      elsif asset = super
        @assets[path.to_s] = @assets[asset.pathname.to_s] = asset
        asset
      end
    end

    protected
      # Cache asset building in persisted cache.
      def build_asset(path, pathname, options)
        # Persisted cache
        cache_asset(pathname.to_s) do
          super
        end
      end

      def expire_index!
        # Clear digest to be recomputed
        @digest = nil
        @assets = {}
      end
  end
end
