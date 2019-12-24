from flask_wtf import FlaskForm
from wtforms import StringField, PasswordField, BooleanField, TextAreaField
from wtforms.validators import InputRequired, Email, Length


class ContactForm(FlaskForm):
    name = StringField('name:', validators=[InputRequired()], render_kw={"placeholder": "name"}) 
    email = StringField('email: ', validators=[InputRequired(), Length(min=6, max=35)], render_kw={"placeholder": "email"}) 
    message = TextAreaField('message', validators=[InputRequired(), Length(min=6, max=20000)], render_kw={"placeholder": "message"}) 

