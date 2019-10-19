function mv_print_progress_bar(x, n, width, erase)
% Prints a progress bar on the console.
%
%Usage:
%  mv_print_progress(pos, max_pos, pattern)
%
%Parameters:
%   x           - [int] current position. It is assumed that x scucessively
%                       takes all positions from 1:n
%   n           - [int] total number of positions
%   width       - [int] width of progress bar in number of characters
%                       excluding the square brackets (default 20)
%   erase       - [bool] if true erase line

if nargin<3, width = 20; end
if nargin<4, erase= false; end

progress = round(x/n * width);
previous_progress = round((x-1)/n * width);

if progress > previous_progress
    if erase
        % erase last positions
        fprintf(repmat('\b',1, width+2-previous_progress));
        
        % update progress bar (at the erased positions)
        fprintf([repmat('=',1, progress-previous_progress) ...
            repmat('>',1, 1) ...
            repmat('.', 1, width-progress) ']'] )
    else
        % print whole progress bar
        fprintf(['[' repmat('=',1, progress-1) ...
            repmat('>',1, 1) ...
            repmat('.', 1, width-progress) ']'] )
    end
end