-- Allow users to delete their own OCR history entries
create policy "Users can delete own ocr history"
  on public.ocr_history for delete
  using (auth.uid() = user_id);
