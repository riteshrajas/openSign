# frozen_string_literal: true

require 'zip'

module Submissions
  module GenerateExportZip
    module_function

    # Generates a ZIP archive containing PDFs for each submitter across all submissions
    # Returns the binary string of the ZIP file
    def call(submissions)
      buffer = Zip::OutputStream.write_buffer do |out|
        submissions.each do |submission|
          submission.submitters.each do |submitter|
            next unless submitter.completed_at # Skip uncompleted submitters
            
            begin
              # Generate combined PDF for each submitter
              combined_attachment = Submissions::GenerateCombinedAttachment.call(submitter)
              pdf_data = combined_attachment.blob.download
              
              # Use a descriptive filename inside the zip
              submitter_name = submitter.name.present? ? "_#{submitter.name.parameterize}" : ""
              filename = "submission_#{submission.id}#{submitter_name}.pdf"
              
              out.put_next_entry(filename)
              out.write(pdf_data)
            rescue StandardError => e
              # Log error and continue with other submitters
              Rails.logger.error("Failed to generate PDF for submitter #{submitter.id}: #{e.message}")
              Rollbar.error(e) if defined?(Rollbar)
            end
          end
        end
      end
      buffer.string
    end
  end
end
