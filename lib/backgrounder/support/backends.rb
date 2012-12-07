module Support
  module Backends

    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def backend=(value)
        @backend = value
        self.configure_backend
      end

      def backend
        return @backend unless @backend.nil?
        if available_backends.empty?
          warn 'WARNING: No queue backends found to use for CarrierWave::Backgrounder. Using the default, :immediate.'
          self.backend = :immediate
        elsif available_backends.size == 1
          self.backend = available_backends.first
        elsif available_backends.size > 1
          warn 'WARNING: Multiple queue backends found for CarrierWave::Backgrounder. You need to set one explicitly.'
        end
      end

      def available_backends
        @available_backends ||= begin
          backends = []
          backends << :girl_friday if defined? ::GirlFriday
          backends << :delayed_job if defined? ::Delayed::Job
          backends << :resque      if defined? ::Resque
          backends << :qu          if defined? ::Qu
          backends << :sidekiq     if defined? ::Sidekiq
          backends << :qc          if defined? ::QC
          backends << :immediate
          backends
        end
      end

      def configure_backend
        if backend == :girl_friday
          require 'girl_friday'
          @girl_friday_queue = GirlFriday::WorkQueue.new(:carrierwave) do |msg|
            worker = msg[:worker]
            worker.perform
          end
        end
      end

      def enqueue_for_backend(worker, class_name, subject_id, mounted_as)
        case backend
        when :girl_friday
          @girl_friday_queue << { :worker => worker.new(class_name, subject_id, mounted_as) }
        when :delayed_job
          ::Delayed::Job.enqueue worker.new(class_name, subject_id, mounted_as)
        when :resque
          ::Resque.enqueue worker, class_name, subject_id, mounted_as
        when :qu
          ::Qu.enqueue worker, class_name, subject_id, column.mounted_as
        when :sidekiq
          ::Sidekiq::Client.enqueue worker, class_name, subject_id, mounted_as
        when :qc
          ::QC.enqueue "#{worker.name}.perform", class_name, subject_id, mounted_as.to_s
        when :immediate
          worker.new(class_name, subject_id, mounted_as).perform
        end
      end

    end
  end
end
